# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group-${var.environment}"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name        = "${var.project_name}-db-subnet-group-${var.environment}"
    Environment = var.environment
  }
}

# RDS PostgreSQL Instance with pgvector support
resource "aws_db_instance" "postgres" {
  identifier     = "${var.project_name}-db-${var.environment}"
  engine         = "postgres"
  engine_version = "15.7" # pgvector is supported in PostgreSQL 15+
  instance_class = "db.t3.micro" # Free tier eligible

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name

  skip_final_snapshot = true # Set to false in production
  deletion_protection = false # Set to true in production

  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"

  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = {
    Name        = "${var.project_name}-db-${var.environment}"
    Environment = var.environment
  }
}

# Store database endpoint in SSM Parameter Store
resource "aws_ssm_parameter" "db_endpoint" {
  name  = "/${var.project_name}/${var.environment}/db/endpoint"
  type  = "String"
  value = aws_db_instance.postgres.endpoint

  tags = {
    Name        = "${var.project_name}-db-endpoint-${var.environment}"
    Environment = var.environment
  }
}

# Store database connection string in SSM Parameter Store
resource "aws_ssm_parameter" "db_connection_string" {
  name  = "/${var.project_name}/${var.environment}/db/connection_string"
  type  = "SecureString"
  value = "postgres://${var.db_username}:${var.db_password}@${aws_db_instance.postgres.endpoint}/${var.db_name}"

  tags = {
    Name        = "${var.project_name}-db-connection-string-${var.environment}"
    Environment = var.environment
  }
} 