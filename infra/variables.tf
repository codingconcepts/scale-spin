###############
# CockroachDB #
###############

variable "cockroachdb_cluster_name" {
  description = "Name of the CockroachDB cluster."
  type        = string
}

variable "cockroachdb_cloud" {
  description = "Cloud provider to run CockroachDB in."
  type        = string
}

variable "cockroachdb_plan" {
  description = "Cloud plan for cluster."
  type        = string
}

variable "cockroachdb_cluster_vcpus" {
  description = "The number of provisioned vCPUs for cluster."
  type        = number
}

variable "cockroachdb_user" {
  description = "Name of the user that will be created."
  type        = string
}

variable "cockroachdb_regions" {
  description = "List of CockroachDB regions to run in."
  type = list(object({
    name    = string
    primary = optional(bool, false)
  }))
}

##########
# Docker #
##########

variable "local_docker_host" {
  description = "Path of the local Docker socket"
  type        = string
}

variable "docker_build_context" {
  description = "Directory for running Docker commands"
  type        = string
}

variable "image_name" {
  description = "Name of the image to push (and pull)"
  type        = string
}

#######
# GCP #
#######

variable "gcp_project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "gcp_environment_variables" {
  description = "Environment variables for each region"
  type        = map(map(string))
}

variable "gcp_repo_name" {
  description = "Name of the GCP repo to store images"
  type        = string
}

variable "gcp_regions" {
  description = "List of regions to deploy to"
  type        = list(string)
}

variable "gcp_service_name" {
  description = "Name of the GCP service to run"
  type        = string
}
