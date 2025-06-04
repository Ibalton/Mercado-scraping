variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "ecs_tasks_sg_id" {
  description = "Security group ID of the ECS tasks"
  type        = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "db_subnet_group" {
  description = "RDS subnet group name"
  type        = string
}
