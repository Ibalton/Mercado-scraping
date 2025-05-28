variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "mercado-scraping"
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "postgres"
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
  default     = "postgres123"
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "cloud"
}

variable "postgres_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "15.7"  # Can be overridden if this version is not available
} 