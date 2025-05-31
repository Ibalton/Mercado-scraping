resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
}

resource "aws_db_subnet_group" "rds" {
  name       = "rds-subnet-group"
  subnet_ids = [aws_subnet.private.id, aws_subnet.private2.id]
  tags = {
    Name = "rds-subnet-group"
  }
}

//Pone un internet gateway sobre la vpc
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

// Agrega las subnets publicas
resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.main.id // Sobre este VPC
  cidr_block        = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone = "us-east-1a"
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"
}
resource "aws_subnet" "private2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1b"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
}

resource "aws_eip" "nat" {
  domain = "vpc"
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_id" {
  value = aws_subnet.public.id
}

output "private_subnet_id" {
  value = aws_subnet.private.id
}
output "private2_subnet_id" {
  value = aws_subnet.private.id
}

output "db_subnet_group" {
  value = aws_db_subnet_group.rds.name
}

output "private_subnet_ids" {
  value = [aws_subnet.private.id,
  aws_subnet.private2.id] # Or add multiple AZs
}
