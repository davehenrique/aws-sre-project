terraform {
  backend "s3" {
    bucket = "terraform-state-dave-sre-project"
    key    = "sre-project/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = "us-east-1"
}

data "aws_caller_identity" "current" {}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "sre-cluster"
}

# Security Group
resource "aws_security_group" "ecs_sg" {
  name = "ecs-sg"

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

# Pega subnets default
data "aws_subnets" "default" {}

# Task Definition
resource "aws_ecs_task_definition" "app" {
  family                   = "sre-task"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  network_mode             = "awsvpc"

  execution_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/ecsTaskExecutionRole"

  container_definitions = jsonencode([{
    name  = "app"
    image = "330745472388.dkr.ecr.us-east-1.amazonaws.com/sre-app:v2"
    portMappings = [{
      containerPort = 80
    }]
  }])
}

# ECS Service
resource "aws_ecs_service" "app" {
  name            = "sre-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }
}