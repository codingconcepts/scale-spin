terraform {
  required_version = ">= 1.9.5"

  required_providers {
    cockroach = {
      source = "cockroachdb/cockroach"
    }
  }
}

resource "cockroach_cluster" "standard" {
  name           = var.cluster_name
  cloud_provider = var.cloud
  plan           = var.plan

  serverless = {
    usage_limits = {
      provisioned_virtual_cpus = var.cluster_vcpus
    }
    upgrade_type = "AUTOMATIC"
  }

  regions           = var.regions
  delete_protection = false
}

resource "random_password" "rob" {
  special = false
  length  = 25
}

resource "cockroach_sql_user" "rob" {
  cluster_id = cockroach_cluster.standard.id
  name       = var.user
  password   = random_password.rob.result
}

resource "cockroach_database" "db" {
  name       = "store"
  cluster_id = cockroach_cluster.standard.id
}