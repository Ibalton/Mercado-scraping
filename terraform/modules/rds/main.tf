resource "aws_security_group" "rds" {
  name   = "mercado-rds"
  vpc_id = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.ecs_tasks_sg_id]
    description     = "Fargate backend to Postgres"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "mercado-rds"
  }
}

resource "aws_db_subnet_group" "default" {
  name       = "rds-subnet-group-epic-and-iunique"
  subnet_ids = var.private_subnet_ids
}

resource "aws_db_instance" "postgres" {
  identifier         = "cloud"
  engine             = "postgres"
  instance_class     = "db.t3.micro"
  allocated_storage  = 20
  db_name            = "postgres"
  username           = "clouduser"
  password           = "replace_with_secret" # Use Secrets Manager or variables!
  db_subnet_group_name    = var.db_subnet_group
  vpc_security_group_ids  = [aws_security_group.rds.id]
  publicly_accessible = false
  skip_final_snapshot = true
  multi_az = false
}

output "rds_endpoint" {
  value = aws_db_instance.postgres.endpoint
}

output "database_url" {
  description = "PostgreSQL connection URL for applications"
  value       = "postgresql+psycopg2://${aws_db_instance.postgres.username}:${aws_db_instance.postgres.password}@${aws_db_instance.postgres.endpoint}/${aws_db_instance.postgres.db_name}"
  sensitive   = true
}
