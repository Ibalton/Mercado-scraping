# Alternative RDS configuration with automatic version detection
# Use this instead of rds-simple.tf if you want automatic version detection

# Data source to get the latest PostgreSQL engine version
data "aws_rds_engine_version" "postgres" {
  engine             = "postgres"
  preferred_versions = ["15.7", "15.6", "15.5", "15.4", "14.12", "14.11"]
}

# DB Subnet Group using default subnets
resource "aws_db_subnet_group" "main_auto" {
  name       = "${var.project_name}-db-subnet-auto"
  subnet_ids = data.aws_subnets.default.ids

  tags = {
    Name = "${var.project_name}-db-subnet-auto"
  }
}

# RDS PostgreSQL Instance with automatic version detection
resource "aws_db_instance" "postgres_auto" {
  identifier     = "${var.project_name}-db-auto"
  engine         = "postgres"
  engine_version = data.aws_rds_engine_version.postgres.version
  instance_class = "db.t3.micro"

  allocated_storage = 20
  storage_type      = "gp2"
  storage_encrypted = false # Disabled for Learner Lab

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main_auto.name

  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Name = "${var.project_name}-db-auto"
  }
}

# Output the detected version
output "postgres_version_detected" {
  description = "PostgreSQL version that was automatically detected"
  value       = data.aws_rds_engine_version.postgres.version
} 