# Configure the AWS Provider
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Create a VPC
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr_block
}

# Create Public and Private Subnets
resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.public_subnet_cidr_block
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet"
  }
}

resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.private_subnet_cidr_block

  tags = {
    Name = "private-subnet"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "igw" {}

# Attach Internet Gateway to VPC
resource "aws_vpc_gateway_attachment" "igw_attachment" {
  vpc_id       = aws_vpc.main.id
  internet_gateway_id = aws_internet_gateway.igw.id
}

# Create Route Table for Public Subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  routes = [
    {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.igw.id
    },
  ]
}

# Create Route Table for Private Subnet
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  routes = [
    {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_nat_gateway.nat.id
    },
  ]
}

# Create NAT Gateway
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.public.id
}

# Create EIP for NAT Gateway
resource "aws_eip" "eip" {
  instance = null
  vpc = true
}

# Associate Route Tables with Subnets
resource "aws_route_table_association" "public_subnet_association" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_subnet_association" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# Create Security Groups
resource "aws_security_group" "allow_all_inbound" {
  name_prefix = "allow_all_inbound"
  vpc_id       = aws_vpc.main.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "allow_http_inbound" {
  name_prefix = "allow_http_inbound"
  vpc_id       = aws_vpc.main.id

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

# Create Fargate Task Definition
resource "aws_ecs_task_definition" "react_app" {
  family = "react-app"

  container_definitions = <<EOF
[
  {
    "name": "react-app",
    "image": "your-ecr-repository-uri:latest", # Replace with your ECR repository URI
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "/ecs/react-app",
        "awslogs-region": "${aws.region}"
      }
    },
    "portMappings": [
      {
        "containerPort": 80,
        "hostPort": 80
      }
    ]
  }
]
EOF
}

# Create Fargate Service
resource "aws_ecs_service" "react_app" {
  cluster = "default" # Or your desired ECS cluster
  desired_count = 1
  launch_type = "FARGATE"
  task_definition = aws_ecs_task_definition.react_app.family

  network_configuration {
    awsvpc_configuration {
      subnets = [aws_subnet.private.id]
      assign_public_ip = "DISABLED"
      security_groups = [aws_security_group.allow_http_inbound.id]
    }
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.react_app.arn
  }

  depends_on = [aws_lb_target_group.react_app]
}

# Create Load Balancer
resource "aws_lb" "react_app" {
  name = "react-app-lb"
  internal = true # Internal load balancer
  subnets = [aws_subnet.public.id]
  security_groups = [aws_security_group.allow_all_inbound.id]
}

# Create Load Balancer Listener
resource "aws_lb_listener" "react_app" {
  load_balancer_arn = aws_lb.react_app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.react_app.arn
  }
}
