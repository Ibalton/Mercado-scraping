variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}


variable "sqs_queue_url" {
  description = "Queue url for scraping requests"
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


variable "sqs_region" {
  description = "SQS region"
}
variable "database_url" {
  description = "Database connection URL"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "backend_image" {
  description = "Backend Docker image URI with immutable tag"
  type        = string
}

variable "frontend_image" {
  description = "Frontend Docker image URI with immutable tag"
  type        = string
} 


variable "scraper_image" {
  description = "Scraper Docker image URI with immutable tag"
  type        = string
} 