

resource "aws_security_group" "rds" {
  name   = "mercado-rds-${var.environment}"
  vpc_id = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = compact([var.ecs_tasks_sg_id, var.lambda_sg_id])
    description     = "Fargate backend and Lambda to Postgres"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "mercado-rds-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_db_instance" "postgres" {
  identifier         = "mercado-${var.environment}"
  engine             = "postgres"
  instance_class     = var.instance_class
  allocated_storage  = 20
  db_name            = "${var.environment}_db"
  username           = "clouduser"
  password           = var.db_password
  db_subnet_group_name    = var.db_subnet_group
  vpc_security_group_ids  = [aws_security_group.rds.id]
  publicly_accessible = false
  skip_final_snapshot = true
  multi_az = var.environment == "prod" ? true : false  # Multi-AZ only for prod

  tags = {
    Name        = "mercado-${var.environment}"
    Environment = var.environment
  }

  # Lifecycle meta-argument to prevent accidental destruction
  lifecycle {
    prevent_destroy = false
    ignore_changes  = [password]
  }
}

output "rds_endpoint" {
  value = aws_db_instance.postgres.endpoint
}

output "database_url" {
  description = "PostgreSQL connection URL for applications"
  value       = "postgresql+psycopg2://${aws_db_instance.postgres.username}:${aws_db_instance.postgres.password}@${aws_db_instance.postgres.endpoint}/${aws_db_instance.postgres.db_name}"
  sensitive   = true
}
