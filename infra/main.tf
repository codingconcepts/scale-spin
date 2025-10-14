terraform {
  required_version = ">= 1.9.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.50"
    }

    cockroach = {
      source = "cockroachdb/cockroach"
    }
  }
}

module "crdb" {
  source = "./modules/crdb"

  cluster_name  = var.cockroachdb_cluster_name
  cloud         = var.cockroachdb_cloud
  plan          = var.cockroachdb_plan
  cluster_vcpus = var.cockroachdb_cluster_vcpus
  user          = var.cockroachdb_user
  regions       = var.cockroachdb_regions
}

module "sqs" {
  source = "./modules/sqs"

  cluster_name_prefix = var.cluster_name_prefix
}

module "ecs" {
  source = "./modules/ecs"

  regions = module.sqs.regions

  cluster_name_prefix = var.cluster_name_prefix
  desired_count       = var.desired_count
  image               = var.image
  database_driver     = var.database_driver
  cockroachdb_url     = module.crdb.global_lb

  us_vpc_id         = module.sqs.us_vpc_id
  us_queue_id       = module.sqs.sqs_queue_ids["us_east_1"]
  us_log_group_name = module.sqs.us_log_group_name
  us_task_exec_arn  = module.sqs.us_task_exec_arn
  us_task_role_arn  = module.sqs.us_task_role_arn

  eu_vpc_id         = module.sqs.eu_vpc_id
  eu_queue_id       = module.sqs.sqs_queue_ids["eu_west_2"]
  eu_log_group_name = module.sqs.eu_log_group_name
  eu_task_exec_arn  = module.sqs.eu_task_exec_arn
  eu_task_role_arn  = module.sqs.eu_task_role_arn

  ap_vpc_id         = module.sqs.ap_vpc_id
  ap_queue_id       = module.sqs.sqs_queue_ids["ap_southeast_1"]
  ap_log_group_name = module.sqs.ap_log_group_name
  ap_task_exec_arn  = module.sqs.ap_task_exec_arn
  ap_task_role_arn  = module.sqs.ap_task_role_arn
}
