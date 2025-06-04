output "backend_image_built" {
  description = "Whether backend image was built and pushed"
  value       = var.auto_build_images ? "true" : "false"
}

output "frontend_image_built" {
  description = "Whether frontend image was built and pushed"
  value       = var.auto_build_images ? "true" : "false"
}

output "backend_task_definition_arn" {
  description = "ARN of the backend task definition"
  value       = aws_ecs_task_definition.backend.arn
}

output "frontend_task_definition_arn" {
  description = "ARN of the frontend task definition"
  value       = aws_ecs_task_definition.frontend.arn
} 