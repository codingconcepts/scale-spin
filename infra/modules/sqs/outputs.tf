output "regions" {
  value = local.regions
}

output "sqs_queue_ids" {
  description = "SQS queue IDs per region"
  value = {
    us_east_1      = aws_sqs_queue.queue_us.id
    eu_west_2      = aws_sqs_queue.queue_eu.id
    ap_southeast_1 = aws_sqs_queue.queue_ap.id
  }
}

output "sqs_queue_urls" {
  description = "SQS queue URLs per region"
  value = {
    us_east_1      = aws_sqs_queue.queue_us.url
    eu_west_2      = aws_sqs_queue.queue_eu.url
    ap_southeast_1 = aws_sqs_queue.queue_ap.url
  }
}

output "us_vpc_id" {
  value = aws_vpc.public_us.id
}

output "us_log_group_name" {
  value = aws_cloudwatch_log_group.logs_us.name
}

output "us_task_exec_arn" {
  value = aws_iam_role.task_exec_us.arn
}

output "us_task_role_arn" {
  value = aws_iam_role.task_role_us.arn
}

output "eu_vpc_id" {
  value = aws_vpc.public_eu.id
}

output "eu_log_group_name" {
  value = aws_cloudwatch_log_group.logs_eu.name
}

output "eu_task_exec_arn" {
  value = aws_iam_role.task_exec_eu.arn
}

output "eu_task_role_arn" {
  value = aws_iam_role.task_role_eu.arn
}

output "ap_vpc_id" {
  value = aws_vpc.public_ap.id
}

output "ap_log_group_name" {
  value = aws_cloudwatch_log_group.logs_ap.name
}

output "ap_task_exec_arn" {
  value = aws_iam_role.task_exec_ap.arn
}

output "ap_task_role_arn" {
  value = aws_iam_role.task_role_ap.arn
}
