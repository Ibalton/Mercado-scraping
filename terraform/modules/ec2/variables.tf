variable "vpc_id" {
  type = string
}

variable "public_subnet_id" {
  type = string
}

variable "private_subnet_id" {
  type = string
}

variable "key_pair_name" {
  type = string
}

variable "ami_id" {
  type = string
}

variable "my_ip" {
  type = string
  description = "Your public IP with /32 mask for SSH access"
}
