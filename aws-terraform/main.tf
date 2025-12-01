terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.0"
}

provider "aws" {
  region = var.aws_region
}

# Data source for existing LabRole
data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

# VPC and Networking
resource "aws_vpc" "geecache_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "geecache-vpc"
  }
}

resource "aws_internet_gateway" "geecache_igw" {
  vpc_id = aws_vpc.geecache_vpc.id

  tags = {
    Name = "geecache-igw"
  }
}

resource "aws_subnet" "geecache_public_subnet_a" {
  vpc_id                  = aws_vpc.geecache_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "geecache-public-a"
  }
}

resource "aws_subnet" "geecache_public_subnet_b" {
  vpc_id                  = aws_vpc.geecache_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true

  tags = {
    Name = "geecache-public-b"
  }
}

resource "aws_route_table" "geecache_public_rt" {
  vpc_id = aws_vpc.geecache_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.geecache_igw.id
  }

  tags = {
    Name = "geecache-public-rt"
  }
}

resource "aws_route_table_association" "public_subnet_a_association" {
  subnet_id      = aws_subnet.geecache_public_subnet_a.id
  route_table_id = aws_route_table.geecache_public_rt.id
}

resource "aws_route_table_association" "public_subnet_b_association" {
  subnet_id      = aws_subnet.geecache_public_subnet_b.id
  route_table_id = aws_route_table.geecache_public_rt.id
}

# Security Group
resource "aws_security_group" "geecache_sg" {
  name        = "geecache-sg"
  description = "Security group for GeeCache ECS tasks"
  vpc_id      = aws_vpc.geecache_vpc.id

  # Cache node ports
  ingress {
    from_port   = 8001
    to_port     = 8003
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # API port
  ingress {
    from_port   = 9999
    protocol    = "tcp"
    to_port     = 9999
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Prometheus metrics port
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "geecache-sg"
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "geecache_logs" {
  name              = "/ecs/geecache"
  retention_in_days = 7

  tags = {
    Name = "geecache-logs"
  }
}

# ECR Repository
resource "aws_ecr_repository" "geecache" {
  name                 = "geecache"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "geecache"
  }
}

# Note: Cloud Map not available in AWS Learner Lab
# Service discovery will use direct IP addresses or DNS

# ECS Cluster
resource "aws_ecs_cluster" "geecache_cluster" {
  name = "geecache-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "geecache-cluster"
  }
}

# ECS Task Definition for Cache Nodes
resource "aws_ecs_task_definition" "geecache_node" {
  family                   = "geecache-node"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = data.aws_iam_role.lab_role.arn
  task_role_arn            = data.aws_iam_role.lab_role.arn

  container_definitions = jsonencode([
    {
      name      = "geecache-node"
      image     = "${aws_ecr_repository.geecache.repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = 8001
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "PORT"
          value = "8001"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.geecache_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "cache-node"
        }
      }

      command = ["-port=8001"]
    }
  ])

  tags = {
    Name = "geecache-node"
  }
}

# ECS Task Definition for API Server
resource "aws_ecs_task_definition" "geecache_api" {
  family                   = "geecache-api"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = data.aws_iam_role.lab_role.arn
  task_role_arn            = data.aws_iam_role.lab_role.arn

  container_definitions = jsonencode([
    {
      name      = "geecache-api"
      image     = "${aws_ecr_repository.geecache.repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = 9999
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.geecache_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "api-server"
        }
      }

      command = ["-api=true", "-port=8001"]
    }
  ])

  tags = {
    Name = "geecache-api"
  }
}

# ECS Service for Cache Nodes (without service discovery due to Learner Lab limitations)
resource "aws_ecs_service" "geecache_nodes" {
  name            = "geecache-nodes"
  cluster         = aws_ecs_cluster.geecache_cluster.id
  task_definition = aws_ecs_task_definition.geecache_node.arn
  desired_count   = var.cache_node_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.geecache_public_subnet_a.id, aws_subnet.geecache_public_subnet_b.id]
    security_groups  = [aws_security_group.geecache_sg.id]
    assign_public_ip = true
  }

  tags = {
    Name = "geecache-nodes-service"
  }
}

# ECS Service for API Server
resource "aws_ecs_service" "geecache_api" {
  name            = "geecache-api"
  cluster         = aws_ecs_cluster.geecache_cluster.id
  task_definition = aws_ecs_task_definition.geecache_api.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.geecache_public_subnet_a.id]
    security_groups  = [aws_security_group.geecache_sg.id]
    assign_public_ip = true
  }

  tags = {
    Name = "geecache-api-service"
  }
}
