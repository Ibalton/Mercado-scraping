variable "vpc_security_group_ids" {
  type = list(string)
}

variable "private_subnet_ids" {
  type = list(string)
  
}
variable "db_subnet_group" {
  description = "RDS subnet group name"
  type        = string
}
