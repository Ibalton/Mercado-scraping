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



module "sqs" {
  source = "./modules/sqs"
}

resource "aws_security_group" "lambda" {
  name   = "lambda-sg"
  vpc_id = module.vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.default_tags
}

# Security group for database access from ECS tasks
resource "aws_security_group" "db_access" {
  name        = "mercado-db-access"
  description = "Security group for database access from ECS tasks"
  vpc_id      = module.vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.default_tags
}

module "rds" {
  for_each = var.environments
  source   = "./modules/rds"

  # Environment-specific configuration
  environment    = each.key
  instance_class = each.value.db_instance_class

  # Common configuration
  vpc_id             = module.vpc.vpc_id
  ecs_tasks_sg_id    = aws_security_group.db_access.id
  db_subnet_group    = module.vpc.db_subnet_group
  private_subnet_ids = module.vpc.private_subnet_ids
  lambda_sg_id       = aws_security_group.lambda.id
  db_password        = var.db_password
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
  database_url       = module.rds[each.key].database_url # Environment-specific DB URL
  aws_region         = var.aws_region
  db_access_sg_id    = aws_security_group.db_access.id

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

  cognito_pool_id   = aws_cognito_user_pool.mercado.id
  cognito_client_id = aws_cognito_user_pool_client.spa.id

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

module "lambda" {
  source                    = "./modules/lambda"
  sqs_queue_url             = module.sqs.scraper_sqs_queue_url
  sqs_region                = var.aws_region
  database_url              = module.rds["prod"].database_url # Lambda uses prod DB by default
  lambda_subnet_ids         = module.vpc.private_subnet_ids
  lambda_security_group_ids = [aws_security_group.lambda.id]
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

output "rds_endpoints" {
  description = "RDS endpoints by environment"
  value       = { for env, rds in module.rds : env => rds.rds_endpoint }
}

output "database_urls" {
  description = "Database connection URLs by environment"
  value       = { for env, rds in module.rds : env => rds.database_url }
  sensitive   = true
}

# -------------------------------------
# Cognito User Pool for SPA authentication
# -------------------------------------

resource "aws_cognito_user_pool" "mercado" {
  name                     = "mercado-scraper-user-pool"
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length    = 8
    require_symbols   = false
    require_numbers   = false
    require_uppercase = false
    require_lowercase = true
  }

  tags = local.default_tags
}

resource "aws_cognito_user_pool_client" "spa" {
  name         = "mercado-scraper-spa-client"
  user_pool_id = aws_cognito_user_pool.mercado.id

  generate_secret              = false # SPA / public client
  explicit_auth_flows          = ["ALLOW_USER_PASSWORD_AUTH", "ALLOW_REFRESH_TOKEN_AUTH", "ALLOW_USER_SRP_AUTH", "ALLOW_CUSTOM_AUTH"]
  supported_identity_providers = ["COGNITO"]

  callback_urls = [
    # Front-end listener DNS will be injected at apply time via Terraform interpolation
    # Using HTTP because Learner Lab does not provision ACM certs by default
    for env, ecs in module.ecs : "${ecs.frontend_url}/login/callback"
  ]

  logout_urls = [
    for env, ecs in module.ecs : "${ecs.frontend_url}"
  ]

  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["email", "openid", "profile"]

  depends_on = [aws_cognito_user_pool.mercado]
}

resource "random_pet" "cognito_domain" {
  length = 2
}

resource "aws_cognito_user_pool_domain" "this" {
  domain       = "mercado-${random_pet.cognito_domain.id}"
  user_pool_id = aws_cognito_user_pool.mercado.id
}

output "cognito_pool_id" {
  description = "ID of the Cognito User Pool"
  value       = aws_cognito_user_pool.mercado.id
}

output "cognito_client_id" {
  description = "ID of the Cognito User Pool client"
  value       = aws_cognito_user_pool_client.spa.id
}

output "cognito_domain" {
  description = "Cognito hosted UI domain"
  value       = aws_cognito_user_pool_domain.this.domain
}


module "s3" {
  source = "./modules/s3"
  
  # Required variables for the S3 module
  vite_build_folder = "../frontend/dist"  # Path to Vite build output
  vite_api_url = module.ecs.backend_url    # Use the backend_url output from the ECS module
}

output "name_of_s3_bucket" {
  description = "Name of the S3 bucket for Vite static site"
  value       = module.s3.s3_bucket_name
  
}

output "s3_bucket_website_url" {
  description = "URL of the S3 bucket website"
  value       = module.s3.s3_bucket_website_url
}