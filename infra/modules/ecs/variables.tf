variable "regions" {
  description = "SQS region configuration."
  type = map(object({
    provider_alias = string
    vpc_id         = string
    subnets        = list(string)
    name_suffix    = string
  }))
}

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

variable "cockroachdb_url" {
  description = "URL to the CockroachDB cluster."
  type        = string
}

variable "database_driver" {
  description = "Name of the database driver to use."
  type        = string
}

variable "us_vpc_id" {
  type = string
}

variable "us_queue_id" {
  description = "ID of the US SQS queue."
  type        = string
}

variable "us_log_group_name" {
  description = "Name of the US CloudWatch Log Group."
  type        = string
}

variable "us_task_exec_arn" {
  description = ""
  type        = string
}

variable "us_task_role_arn" {
  description = ""
  type        = string
}

variable "eu_vpc_id" {
  type = string
}

variable "eu_queue_id" {
  description = "ID of the EU SQS queue."
  type        = string
}

variable "eu_log_group_name" {
  description = "Name of the EU CloudWatch Log Group."
  type        = string
}

variable "eu_task_exec_arn" {
  description = ""
  type        = string
}

variable "eu_task_role_arn" {
  description = ""
  type        = string
}

variable "ap_vpc_id" {
  type = string
}

variable "ap_queue_id" {
  description = "ID of the AP SQS queue."
  type        = string
}

variable "ap_log_group_name" {
  description = "Name of the AP CloudWatch Log Group."
  type        = string
}

variable "ap_task_exec_arn" {
  description = ""
  type        = string
}

variable "ap_task_role_arn" {
  description = ""
  type        = string
}
