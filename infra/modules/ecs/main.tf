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

############################
# ECS clusters (per region)
############################
resource "aws_ecs_cluster" "cluster_us" {
  name = "${var.cluster_name_prefix}-us"
}

resource "aws_ecs_cluster" "cluster_eu" {
  provider = aws.eu_west_2
  name     = "${var.cluster_name_prefix}-eu"
}

resource "aws_ecs_cluster" "cluster_ap" {
  provider = aws.ap_southeast_1
  name     = "${var.cluster_name_prefix}-ap"
}

############################
# Security groups (ALB + tasks)
############################

# us-east-1
resource "aws_security_group" "alb_us" {
  name   = "${var.cluster_name_prefix}-alb-us"
  vpc_id = var.us_vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "tasks_us" {
  name   = "${var.cluster_name_prefix}-tasks-us"
  vpc_id = var.us_vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_us.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# eu-west-2
resource "aws_security_group" "alb_eu" {
  provider = aws.eu_west_2
  name     = "${var.cluster_name_prefix}-alb-eu"
  vpc_id   = var.eu_vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "tasks_eu" {
  provider = aws.eu_west_2
  name     = "${var.cluster_name_prefix}-tasks-eu"
  vpc_id   = var.eu_vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_eu.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ap-southeast-1
resource "aws_security_group" "alb_ap" {
  provider = aws.ap_southeast_1
  name     = "${var.cluster_name_prefix}-alb-ap"
  vpc_id   = var.ap_vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "tasks_ap" {
  provider = aws.ap_southeast_1
  name     = "${var.cluster_name_prefix}-tasks-ap"
  vpc_id   = var.ap_vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_ap.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

############################
# ALBs + TGs + Listeners
############################

# us-east-1
resource "aws_lb" "alb_us" {
  name               = "${var.cluster_name_prefix}-alb-us"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_us.id]
  subnets            = var.regions["us_east_1"].subnets

  tags = {
    Name = "${var.cluster_name_prefix}-alb"
  }

  lifecycle {
    precondition {
      condition     = length(var.regions["us_east_1"].subnets) >= 2
      error_message = "At least 2 subnets are required. Found: ${length(var.regions["us_east_1"].subnets)}"
    }
  }
}

resource "aws_lb_target_group" "tg_us" {
  name        = "${var.cluster_name_prefix}-tg-us"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.us_vpc_id
  target_type = "ip"

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 5
    timeout             = 5
    interval            = 30
    matcher             = "200-399"
  }
}

resource "aws_lb_listener" "listener_us" {
  load_balancer_arn = aws_lb.alb_us.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg_us.arn
  }
}

# eu-west-2
resource "aws_lb" "alb_eu" {
  provider           = aws.eu_west_2
  name               = "${var.cluster_name_prefix}-alb-eu"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_eu.id]
  subnets            = var.regions["eu_west_2"].subnets

  tags = {
    Name = "${var.cluster_name_prefix}-alb"
  }

  lifecycle {
    precondition {
      condition     = length(var.regions["eu_west_2"].subnets) >= 2
      error_message = "At least 2 subnets are required. Found: ${length(var.regions["eu_west_2"].subnets)}"
    }
  }
}

resource "aws_lb_target_group" "tg_eu" {
  provider    = aws.eu_west_2
  name        = "${var.cluster_name_prefix}-tg-eu"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.eu_vpc_id
  target_type = "ip"

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 5
    timeout             = 5
    interval            = 30
    matcher             = "200-399"
  }
}

resource "aws_lb_listener" "listener_eu" {
  provider          = aws.eu_west_2
  load_balancer_arn = aws_lb.alb_eu.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg_eu.arn
  }
}

# ap-southeast-1
resource "aws_lb" "alb_ap" {
  provider           = aws.ap_southeast_1
  name               = "${var.cluster_name_prefix}-alb-ap"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_ap.id]
  subnets            = var.regions["ap_southeast_1"].subnets

  tags = {
    Name = "${var.cluster_name_prefix}-alb"
  }

  lifecycle {
    precondition {
      condition     = length(var.regions["ap_southeast_1"].subnets) >= 2
      error_message = "At least 2 subnets are required. Found: ${length(var.regions["ap_southeast_1"].subnets)}"
    }
  }
}

resource "aws_lb_target_group" "tg_ap" {
  provider    = aws.ap_southeast_1
  name        = "${var.cluster_name_prefix}-tg-ap"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.ap_vpc_id
  target_type = "ip"

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 5
    timeout             = 5
    interval            = 30
    matcher             = "200-399"
  }
}

resource "aws_lb_listener" "listener_ap" {
  provider          = aws.ap_southeast_1
  load_balancer_arn = aws_lb.alb_ap.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg_ap.arn
  }
}

############################
# Task definitions (per region)
############################
resource "aws_ecs_task_definition" "taskdef_us" {
  family                   = "${var.cluster_name_prefix}-task-us"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "1024"
  memory                   = "4096"
  execution_role_arn       = var.us_task_exec_arn
  task_role_arn            = var.us_task_role_arn

  container_definitions = jsonencode([
    {
      name         = "app"
      image        = var.image
      essential    = true
      portMappings = [{ containerPort = 3000, protocol = "tcp" }]
      environment = [
        { name = "SQS_QUEUE_URL", value = var.us_queue_id },
        { name = "DATABASE_DRIVER", value = var.database_driver },
        { name = "DATABASE_URL", value = var.cockroachdb_url },
        { name = "COCKROACHDB_REGION", value = "aws-us-east-1" },
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = var.us_log_group_name
          awslogs-region        = "us-east-1"
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_task_definition" "taskdef_eu" {
  provider                 = aws.eu_west_2
  family                   = "${var.cluster_name_prefix}-task-eu"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "1024"
  memory                   = "4096"
  execution_role_arn       = var.eu_task_exec_arn
  task_role_arn            = var.eu_task_role_arn

  container_definitions = jsonencode([
    {
      name         = "app"
      image        = var.image
      essential    = true
      portMappings = [{ containerPort = 3000, protocol = "tcp" }]
      environment = [
        { name = "SQS_QUEUE_URL", value = var.eu_queue_id },
        { name = "DATABASE_DRIVER", value = var.database_driver },
        { name = "DATABASE_URL", value = var.cockroachdb_url },
        { name = "COCKROACHDB_REGION", value = "aws-eu-west-2" },
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = var.eu_log_group_name
          awslogs-region        = "eu-west-2"
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_task_definition" "taskdef_ap" {
  provider                 = aws.ap_southeast_1
  family                   = "${var.cluster_name_prefix}-task-ap"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "1024"
  memory                   = "4096"
  execution_role_arn       = var.ap_task_exec_arn
  task_role_arn            = var.ap_task_role_arn

  container_definitions = jsonencode([
    {
      name         = "app"
      image        = var.image
      essential    = true
      portMappings = [{ containerPort = 3000, protocol = "tcp" }]
      environment = [
        { name = "SQS_QUEUE_URL", value = var.ap_queue_id },
        { name = "DATABASE_DRIVER", value = var.database_driver },
        { name = "DATABASE_URL", value = var.cockroachdb_url },
        { name = "COCKROACHDB_REGION", value = "aws-ap-southeast-1" },
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = var.ap_log_group_name
          awslogs-region        = "ap-southeast-1"
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

############################
# ECS services (per region)
############################
resource "aws_ecs_service" "svc_us" {
  name                       = "${var.cluster_name_prefix}-svc-us"
  cluster                    = aws_ecs_cluster.cluster_us.id
  task_definition            = aws_ecs_task_definition.taskdef_us.arn
  desired_count              = var.desired_count
  launch_type                = "FARGATE"

  network_configuration {
    subnets          = var.regions["us_east_1"].subnets
    security_groups  = [aws_security_group.tasks_us.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.tg_us.arn
    container_name   = "app"
    container_port   = 3000
  }
}

resource "aws_ecs_service" "svc_eu" {
  provider                   = aws.eu_west_2
  name                       = "${var.cluster_name_prefix}-svc-eu"
  cluster                    = aws_ecs_cluster.cluster_eu.id
  task_definition            = aws_ecs_task_definition.taskdef_eu.arn
  desired_count              = var.desired_count
  launch_type                = "FARGATE"

  network_configuration {
    subnets          = var.regions["eu_west_2"].subnets
    security_groups  = [aws_security_group.tasks_eu.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.tg_eu.arn
    container_name   = "app"
    container_port   = 3000
  }
}

resource "aws_ecs_service" "svc_ap" {
  provider                   = aws.ap_southeast_1
  name                       = "${var.cluster_name_prefix}-svc-ap"
  cluster                    = aws_ecs_cluster.cluster_ap.id
  task_definition            = aws_ecs_task_definition.taskdef_ap.arn
  desired_count              = var.desired_count
  launch_type                = "FARGATE"

  network_configuration {
    subnets          = var.regions["ap_southeast_1"].subnets
    security_groups  = [aws_security_group.tasks_ap.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.tg_ap.arn
    container_name   = "app"
    container_port   = 3000
  }
}
