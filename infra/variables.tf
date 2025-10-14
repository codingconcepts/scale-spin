# CockroachDB

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

# SQS

variable "cluster_name_prefix" {
  description = "The value that will prefix all ECS cluster names."
  type        = string
}

variable "desired_count" {
  description = "The number of Fargate services to run in each region."
  type        = number
}

variable "image" {
  description = "Docker image name."
  type        = string
}

variable "database_driver" {
  description = "Name of the database driver to use."
  type        = string
}
