# Default tags for all resources
locals {
  default_tags = {
    Project   = "mercado-scraper"
    ManagedBy = "Terraform"
    Owner     = "Cloud-Course"
  }
}

module "vpc" {
  source = "./modules/vpc"

  vpc_cidr     = var.vpc_cidr
  environment  = "dev" # Default environment for shared resources
  default_tags = local.default_tags
}

module "ecr" {
  source = "./modules/ecr"
}

output "ecr_repo_url" {
  value = module.ecr.ecr_repo_url
}

module "ec2" {
  source            = "./modules/ec2"
  vpc_id            = module.vpc.vpc_id
  public_subnet_id  = module.vpc.public_subnet_id
  private_subnet_id = module.vpc.private_subnet_id
  ami_id            = var.ami_id
  key_pair_name     = var.key_pair_name
  my_ip             = var.my_ip
}

module "sqs" {
  source = "./modules/sqs"
}

module "rds" {
  source             = "./modules/rds"
  vpc_id             = module.vpc.vpc_id
  ecs_tasks_sg_id    = module.ecs["dev"].ecs_tasks_sg_id
  db_subnet_group    = module.vpc.db_subnet_group
  private_subnet_ids = module.vpc.private_subnet_ids
}

module "ecr_build" {
  source = "./modules/ecr_build"

  # Required variables for the build module
  ecr_repository_url = module.ecr.ecr_repo_url
  aws_region         = var.aws_region
  repository_name    = "mercado-scraper" # Match the ECR repo name
  project_root       = ".."              # Parent directory with backend/frontend folders
  auto_build_images  = true              # Enable building!

  depends_on = [module.ecr]
}

# for_each for multiple environments
module "ecs" {
  for_each = var.environments
  source   = "./modules/ecs"

  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids
  ecr_repository_url = module.ecr.ecr_repo_url
  database_url       = module.rds.database_url
  aws_region         = var.aws_region

  # Environment-specific configuration
  environment       = each.key
  backend_replicas  = each.value.backend_replicas
  frontend_replicas = each.value.frontend_replicas
  scraper_replicas  = each.value.scraper_replicas
  default_tags      = local.default_tags

  # Use image URIs from ECR build module with immutable tags
  backend_image  = module.ecr_build.backend_image
  frontend_image = module.ecr_build.frontend_image
  scraper_image  = module.ecr_build.scraper_image

  sqs_queue_url = module.sqs.scraper_sqs_queue_url
  sqs_region    = var.aws_region

  depends_on = [module.ecr_build]
}

# Monitoring module for each environment
module "monitoring" {
  for_each = var.environments
  source   = "./modules/monitoring"

  environment              = each.key
  ecs_cluster_name         = module.ecs[each.key].ecs_cluster_name
  ecs_service_name         = "${each.key}-mercado-backend-service"
  load_balancer_arn_suffix = module.ecs[each.key].load_balancer_arn_suffix
  tags                     = local.default_tags
}

# ECS-related outputs for each environment
output "ecs_cluster_names" {
  description = "Names of the ECS clusters by environment"
  value       = { for env, ecs in module.ecs : env => ecs.ecs_cluster_name }
}

output "backend_urls" {
  description = "Backend API URLs by environment"
  value       = { for env, ecs in module.ecs : env => ecs.backend_url }
}

output "frontend_urls" {
  description = "Frontend application URLs by environment"
  value       = { for env, ecs in module.ecs : env => ecs.frontend_url }
}

output "load_balancer_dns_names" {
  description = "Load balancer DNS names by environment"
  value       = { for env, ecs in module.ecs : env => ecs.load_balancer_dns_name }
}

output "monitoring_sns_topics" {
  description = "SNS topic ARNs for monitoring alerts by environment"
  value       = { for env, mon in module.monitoring : env => mon.sns_topic_arn }
}

