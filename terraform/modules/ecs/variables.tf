variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "ecr_repository_url" {
  description = "ECR repository URL"
  type        = string
}

variable "database_url" {
  description = "Database connection URL"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "backend_task_definition_arn" {
  description = "ARN of the backend task definition from ECR build module"
  type        = string
}

variable "frontend_task_definition_arn" {
  description = "ARN of the frontend task definition from ECR build module"
  type        = string
} 