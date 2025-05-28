output "alb_url" {
  description = "URL of the application"
  value       = "http://${aws_lb.main.dns_name}"
}

output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.postgres.endpoint
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "next_steps" {
  description = "Next steps after deployment"
  value = <<-EOT
    1. Access your application at: ${aws_lb.main.dns_name}
    2. Initialize the database:
       - Install PostgreSQL client
       - Run: psql -h ${aws_db_instance.postgres.address} -U ${var.db_username} -d ${var.db_name} -c "CREATE EXTENSION IF NOT EXISTS vector;"
       - Import your data: psql -h ${aws_db_instance.postgres.address} -U ${var.db_username} -d ${var.db_name} < ../backend/db_dump.sql
    3. Update ECS task definitions with your actual application code
  EOT
} 