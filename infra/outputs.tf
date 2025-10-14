###############
# CockroachDB #
###############

output "cockroachdb_global_url" {
  description = "The global load balancer URL for CockroachDB."
  sensitive   = true
  value       = module.crdb.global_lb
}

#######
# SQS #
#######

output "sqs_queue_ids" {
  value = module.sqs.sqs_queue_ids
}

output "sqs_queue_urls" {
  description = "SQS queue URLs per region."
  value = module.sqs.sqs_queue_urls
}

#######
# MCS #
#######

output "alb_urls" {
  description = "Public ALB DNS names per region."
  value = module.ecs.alb_urls
}
