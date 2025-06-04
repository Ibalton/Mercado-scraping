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
  vpc_security_group_ids  = var.vpc_security_group_ids
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
