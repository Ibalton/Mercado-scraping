output "ecs_cluster_id" {
  description = "ID of the ECS cluster"
  value       = aws_ecs_cluster.mercado_cluster.id
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.mercado_cluster.name
}

output "ecs_tasks_sg_id" {
  description = "Security group ID for ECS tasks"
  value       = aws_security_group.ecs_tasks.id
}

output "backend_service_name" {
  description = "Name of the backend ECS service"
  value       = length(aws_ecs_service.backend) > 0 ? aws_ecs_service.backend[0].name : null
}



output "scraper_service_name" {
  description = "Name of the scraper ECS service"
  value       = length(aws_ecs_service.scraper) > 0 ? aws_ecs_service.scraper[0].name : null
}

output "load_balancer_dns_name" {
  description = "Load balancer DNS name"
  value       = aws_lb.main.dns_name
}

output "load_balancer_hosted_zone_id" {
  description = "Hosted zone ID of the Application Load Balancer"
  value       = aws_lb.main.zone_id
}

output "backend_url" {
  description = "Backend API URL"
  value       = "http://${aws_lb.main.dns_name}/api"
}


output "load_balancer_arn_suffix" {
  description = "ARN suffix of the load balancer for monitoring"
  value       = aws_lb.main.arn_suffix
} 