aws_region = "us-east-1"
# terraform.tfvars

vpc_cidr            = "10.0.0.0/16"
public_subnet_cidr  = "10.0.1.0/24"
private_subnet_cidr = "10.0.2.0/24"
availability_zone   = "us-east-1a"

public_key_path = "~/.ssh/mercado.pub"

db_password = "super_secure_password_123"