variable "aws_region" {
  type        = string
  description = "AWS Region"
}

variable "vpc_cidr_block" {
  type        = string
  description = "VPC CIDR Block"
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr_block" {
  type        = string
  description = "Public Subnet CIDR Block"
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr_block" {
  type        = string
  description = "Private Subnet CIDR Block"
  default     = "10.0.2.0/24"
}

variable "ecr_repository_uri" {
  type        = string
  description = "ECR Repository URI"
}