module "vpc" {
  source = "./modules/vpc"
}

module "ecr"{
  source = "./modules/ecr"
}

output "ecr_repo_url" {
  value = module.ecr.ecr_repo_url
}

module "ec2" {
  source             = "./modules/ec2"
  vpc_id             = module.vpc.vpc_id
  public_subnet_id   = module.vpc.public_subnet_id
  private_subnet_id  = module.vpc.private_subnet_id
  ami_id             = var.ami_id
  key_pair_name      = var.key_pair_name
  my_ip              = var.my_ip
}

module "sqs" {
  source = "./modules/sqs"
}
module "rds" {
  source             = "./modules/rds"
  vpc_id             = module.vpc.vpc_id
  ecs_tasks_sg_id    = module.ecs.ecs_tasks_sg_id
  db_subnet_group    = module.vpc.db_subnet_group
  private_subnet_ids = module.vpc.private_subnet_ids

}

module "ecr_build" {
  source = "./modules/ecr_build"
  
  # Required variables for the build module
  ecr_repository_url = module.ecr.ecr_repo_url
  aws_region         = var.aws_region
  repository_name    = "mercado-scraper"     # Match the ECR repo name
  project_root       = ".."                  # Parent directory with backend/frontend folders
  auto_build_images  = true                  # Enable building!
  
  depends_on = [module.ecr]
}

module "ecs" {
  source              = "./modules/ecs"
  vpc_id              = module.vpc.vpc_id
  public_subnet_ids   = module.vpc.public_subnet_ids
  private_subnet_ids  = module.vpc.private_subnet_ids
  ecr_repository_url  = module.ecr.ecr_repo_url
  database_url        = module.rds.database_url
  aws_region          = var.aws_region
  
  # Use image URIs from ECR build module with immutable tags
  backend_image  = module.ecr_build.backend_image
  frontend_image = module.ecr_build.frontend_image
  scraper_image = module.ecr_build.scraper_image

  sqs_queue_url = module.sqs.scraper_sqs_queue_url
  sqs_region = var.aws_region
  
  
  depends_on = [module.ecr_build]
}

# ECS-related outputs
output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs.ecs_cluster_name
}

output "backend_url" {
  description = "Backend API URL"
  value       = module.ecs.backend_url
}

output "frontend_url" {
  description = "Frontend application URL"
  value       = module.ecs.frontend_url
}

output "load_balancer_dns" {
  description = "Load balancer DNS name"
  value       = module.ecs.load_balancer_dns_name
}

