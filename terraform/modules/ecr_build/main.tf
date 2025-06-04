###############################################################################
# produce one immutable tag per plan/apply
###############################################################################
locals {
  ts            = formatdate("YYYYMMDD-HHmmss", timestamp())
  backend_tag   = "backend-${local.ts}"
  frontend_tag  = "frontend-${local.ts}"
  repo_url      = var.ecr_repository_url                # 664122075535.dkr.ecr.us-east-1.amazonaws.com/mercado-scraper
  backend_image = "${local.repo_url}:${local.backend_tag}"
  frontend_image= "${local.repo_url}:${local.frontend_tag}"
}

###############################################################################
# build & push (still using null_resource, but at least with immutable tags)
###############################################################################
resource "null_resource" "push_backend" {
  triggers = { tag = local.backend_tag }                # forces rebuild only when tag changes

  provisioner "local-exec" {
    command = "aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${local.repo_url} && docker build -t ${local.backend_image} ./backend && docker push ${local.backend_image}"
    working_dir = var.project_root
  }
}

resource "null_resource" "push_frontend" {
  triggers = { tag = local.frontend_tag }
  provisioner "local-exec" {
    command = "aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${local.repo_url} && docker build -t ${local.frontend_image} ./frontend && docker push ${local.frontend_image}"
    working_dir = var.project_root
  }
  depends_on = [null_resource.push_backend]
}

###############################################################################
# pin the task definition to the immutable tag
###############################################################################
resource "aws_ecs_task_definition" "backend" {
  family                   = "mercado-backend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = "arn:aws:iam::664122075535:role/LabRole"
  task_role_arn            = "arn:aws:iam::664122075535:role/LabRole"

  container_definitions = jsonencode([
    {
      name  = "backend"
      image = local.backend_image          # <-- immutable!
      essential = true
      
      portMappings = [{ 
        containerPort = 8000
        protocol      = "tcp"
      }]
      
      environment = [
        {
          name  = "DATABASE_URL"
          value = var.database_url
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/mercado-backend"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
          "awslogs-create-group"  = "true"
        }
      }
    }
  ])

  depends_on = [null_resource.push_backend]
}

resource "aws_ecs_task_definition" "frontend" {
  family                   = "mercado-frontend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = "arn:aws:iam::664122075535:role/LabRole"
  task_role_arn            = "arn:aws:iam::664122075535:role/LabRole"

  container_definitions = jsonencode([
    {
      name  = "frontend"
      image = local.frontend_image          # <-- immutable!
      essential = true
      
      portMappings = [{ 
        containerPort = 80
        protocol      = "tcp"
      }]
      
      environment = [
        {
          name  = "VITE_API_URL"
          value = var.backend_api_url
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/mercado-frontend"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
          "awslogs-create-group"  = "true"
        }
      }
    }
  ])

  depends_on = [null_resource.push_frontend]
}