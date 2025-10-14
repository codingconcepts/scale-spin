terraform {
  required_version = ">= 1.9.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.50"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

provider "aws" {
  alias  = "eu_west_2"
  region = "eu-west-2"
}

provider "aws" {
  alias  = "ap_southeast_1"
  region = "ap-southeast-1"
}

locals {
  regions = {
    us_east_1 = {
      provider_alias = "default"
      vpc_id         = aws_vpc.public_us.id
      subnets        = aws_subnet.public_us[*].id
      name_suffix    = "us-east-1"
    }

    eu_west_2 = {
      provider_alias = "eu_west_2"
      vpc_id         = aws_vpc.public_eu.id
      subnets        = aws_subnet.public_eu[*].id
      name_suffix    = "eu-west-2"
    }

    ap_southeast_1 = {
      provider_alias = "ap_southeast_1"
      vpc_id         = aws_vpc.public_ap.id
      subnets        = aws_subnet.public_ap[*].id
      name_suffix    = "ap-southeast-1"
    }
  }
}

############################
# IAM (per region)
############################

# Execution role policy (AWS managed)
data "aws_iam_policy" "ecs_task_execution" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# --- us-east-1 ---
resource "aws_iam_role" "task_exec_us" {
  name               = "ecsTaskExecutionRole-us-east-1"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

resource "aws_iam_role_policy_attachment" "task_exec_attach_us" {
  role       = aws_iam_role.task_exec_us.name
  policy_arn = data.aws_iam_policy.ecs_task_execution.arn
}

resource "aws_iam_role" "task_role_us" {
  name               = "ecsTaskRole-us-east-1"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

# --- eu-west-2 ---
resource "aws_iam_role" "task_exec_eu" {
  provider           = aws.eu_west_2
  name               = "ecsTaskExecutionRole-eu-west-2"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

resource "aws_iam_role_policy_attachment" "task_exec_attach_eu" {
  provider   = aws.eu_west_2
  role       = aws_iam_role.task_exec_eu.name
  policy_arn = data.aws_iam_policy.ecs_task_execution.arn
}

resource "aws_iam_role" "task_role_eu" {
  provider           = aws.eu_west_2
  name               = "ecsTaskRole-eu-west-2"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

# --- ap-southeast-1 ---
resource "aws_iam_role" "task_exec_ap" {
  provider           = aws.ap_southeast_1
  name               = "ecsTaskExecutionRole-ap-southeast-1"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

resource "aws_iam_role_policy_attachment" "task_exec_attach_ap" {
  provider   = aws.ap_southeast_1
  role       = aws_iam_role.task_exec_ap.name
  policy_arn = data.aws_iam_policy.ecs_task_execution.arn
}

resource "aws_iam_role" "task_role_ap" {
  provider           = aws.ap_southeast_1
  name               = "ecsTaskRole-ap-southeast-1"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

############################
# SQS queues (per region) and allow task roles
############################
resource "aws_sqs_queue" "queue_us" {
  name = "${var.cluster_name_prefix}-queue-us"
}

resource "aws_sqs_queue" "queue_eu" {
  provider = aws.eu_west_2
  name     = "${var.cluster_name_prefix}-queue-eu"
}

resource "aws_sqs_queue" "queue_ap" {
  provider = aws.ap_southeast_1
  name     = "${var.cluster_name_prefix}-queue-ap"
}

# Inline policies granting minimal SQS access for app
resource "aws_iam_role_policy" "task_policy_us" {
  name = "ecsTaskSQSPolicy-us-east-1"
  role = aws_iam_role.task_role_us.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["sqs:SendMessage", "sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueUrl", "sqs:GetQueueAttributes"],
      Resource = aws_sqs_queue.queue_us.arn
    }]
  })
}

resource "aws_iam_role_policy" "task_policy_eu" {
  provider = aws.eu_west_2
  name     = "ecsTaskSQSPolicy-eu-west-2"
  role     = aws_iam_role.task_role_eu.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["sqs:SendMessage", "sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueUrl", "sqs:GetQueueAttributes"],
      Resource = aws_sqs_queue.queue_eu.arn
    }]
  })
}

resource "aws_iam_role_policy" "task_policy_ap" {
  provider = aws.ap_southeast_1
  name     = "ecsTaskSQSPolicy-ap-southeast-1"
  role     = aws_iam_role.task_role_ap.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["sqs:SendMessage", "sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueUrl", "sqs:GetQueueAttributes"],
      Resource = aws_sqs_queue.queue_ap.arn
    }]
  })
}

############################
# CloudWatch Logs (per region)
############################
resource "aws_cloudwatch_log_group" "logs_us" {
  name              = "/ecs/${var.cluster_name_prefix}-us"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "logs_eu" {
  provider          = aws.eu_west_2
  name              = "/ecs/${var.cluster_name_prefix}-eu"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "logs_ap" {
  provider          = aws.ap_southeast_1
  name              = "/ecs/${var.cluster_name_prefix}-ap"
  retention_in_days = 14
}


