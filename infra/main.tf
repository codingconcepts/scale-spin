terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }

    cockroach = {
      source = "cockroachdb/cockroach"
    }

    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {
  host = var.local_docker_host

  registry_auth {
    address  = "${google_artifact_registry_repository.repo.location}-docker.pkg.dev"
    username = "oauth2accesstoken"
    password = data.google_service_account_access_token.repo_writer.access_token
  }
}

provider "google" {
  project = var.gcp_project_id
}

###############
# CockroachDB #
###############

resource "cockroach_cluster" "standard" {
  name           = var.cockroachdb_cluster_name
  cloud_provider = var.cockroachdb_cloud
  plan           = var.cockroachdb_plan

  serverless = {
    usage_limits = {
      provisioned_virtual_cpus = var.cockroachdb_cluster_vcpus
    }
    upgrade_type = "AUTOMATIC"
  }

  regions           = var.cockroachdb_regions
  delete_protection = false
}

resource "random_password" "spin" {
  special = false
  length  = 25
}

resource "cockroach_sql_user" "spin" {
  cluster_id = cockroach_cluster.standard.id
  name       = var.cockroachdb_user
  password   = random_password.spin.result
}

resource "cockroach_database" "db" {
  name       = "bank"
  cluster_id = cockroach_cluster.standard.id
}

locals {
  cockroachdb_global_url = format(
    "postgres://%s:%s@%s:26257/bank?sslmode=verify-full",
    var.cockroachdb_user,
    random_password.spin.result,
    replace(
      cockroach_cluster.standard.regions[0].sql_dns,
      "/\\.gcp-[^.]+\\./",
      "."
    )
  )
}

##########
# Docker #
##########

resource "docker_image" "source" {
  name = var.image_name
}

resource "docker_tag" "target" {
  source_image = docker_image.source.name
  target_image = "${google_artifact_registry_repository.repo.location}-docker.pkg.dev/${google_artifact_registry_repository.repo.project}/${google_artifact_registry_repository.repo.repository_id}/${var.image_name}"
}

resource "docker_registry_image" "push" {
  name = docker_tag.target.target_image

  depends_on = [
    google_artifact_registry_repository.repo,
    docker_tag.target
  ]
}

#######
# GCP #
#######

data "google_service_account_access_token" "repo_writer" {
  target_service_account = google_service_account.pusher.email
  scopes                 = ["https://www.googleapis.com/auth/cloud-platform"]
  lifetime               = "3600s"
}

resource "google_project_service" "artifact_registry" {
  project = var.gcp_project_id
  service = "artifactregistry.googleapis.com"
}

resource "google_artifact_registry_repository" "repo" {
  project       = var.gcp_project_id
  location      = var.gcp_regions[0]
  repository_id = var.gcp_repo_name
  format        = "DOCKER"
  depends_on    = [google_project_service.artifact_registry]
}

resource "google_service_account" "pusher" {
  account_id   = "tf-image-pusher"
  display_name = "Terraform image pusher"
}

resource "google_artifact_registry_repository_iam_member" "writer" {
  project    = var.gcp_project_id
  location   = var.gcp_regions[0]
  repository = google_artifact_registry_repository.repo.repository_id
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.pusher.email}"
}

resource "google_artifact_registry_repository_iam_member" "deleter" {
  project    = var.gcp_project_id
  location   = var.gcp_regions[0]
  repository = google_artifact_registry_repository.repo.repository_id
  role       = "roles/artifactregistry.repoAdmin"
  member     = "serviceAccount:${google_service_account.pusher.email}"
}

resource "google_service_account_key" "pusher" {
  service_account_id = google_service_account.pusher.name
}

resource "google_cloud_run_v2_service" "crdb_scale_spin" {
  for_each = toset(var.gcp_regions)

  name     = var.gcp_service_name
  location = each.value
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    containers {
      image = var.image_name

      resources {
        limits = {
          cpu    = "4"
          memory = "2048Mi"
        }
      }

      startup_probe {
        http_get {
          path = "/healthz"
          port = 8080
        }
        timeout_seconds = 10
      }

      env {
        name  = "DATABASE_URL"
        value = local.cockroachdb_global_url
      }

      dynamic "env" {
        for_each = lookup(var.gcp_environment_variables, each.value, {})

        content {
          name  = env.key
          value = env.value
        }
      }
    }
  }
}

resource "google_cloud_run_v2_service_iam_member" "public_access" {
  for_each = toset(var.gcp_regions)

  project  = google_cloud_run_v2_service.crdb_scale_spin[each.key].project
  location = google_cloud_run_v2_service.crdb_scale_spin[each.key].location
  name     = google_cloud_run_v2_service.crdb_scale_spin[each.key].name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

###########
# Outputs #
###########

output "service_urls" {
  description = "URLs of deployed Cloud Run services"
  value = {
    for region, service in google_cloud_run_v2_service.crdb_scale_spin :
    region => service.uri
  }
}

output "cockroachdb_global_url" {
  description = "The global load balancer URL for CockroachDB."
  sensitive   = true
  value       = local.cockroachdb_global_url
}