variable "cluster_name" {
  description = "Name of the CockroachDB cluster."
  type        = string
}

variable "cloud" {
  description = "Cloud provider to run CockroachDB in."
  type        = string
}

variable "plan" {
  description = "Cloud plan for cluster."
  type        = string
}

variable "cluster_vcpus" {
  description = "The number of provisioned vCPUs for cluster."
  type        = number
}

variable "user" {
  description = "Name of the user that will be created."
  type        = string
}

variable "regions" {
  description = "List of CockroachDB regions to run in."
  type = list(object({
    name    = string
    primary = optional(bool, false)
  }))
}
