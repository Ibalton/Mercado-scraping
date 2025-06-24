# ECS Cluster
resource "aws_ecs_cluster" "mercado_cluster" {
  name = "${var.environment}-mercado-scraper-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = local.common_tags
}

# Use existing IAM roles from AWS Learner Lab
data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

# Local values for common configurations
locals {
  # Function 4: merge for combining tags
  common_tags = merge(
    var.default_tags,
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Project     = "mercado-scraper"
    }
  )
}

# Security Group for ECS Tasks
resource "aws_security_group" "ecs_tasks" {
  name        = "${var.environment}-mercado-ecs-tasks"
  description = "Security group for ECS tasks"
  vpc_id      = var.vpc_id

  # Allow ALBs to reach the tasks only on required ports
  ingress {
    description     = "Public ALB to frontend containers (:80)"
    protocol        = "tcp"
    from_port       = 80
    to_port         = 80
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description     = "Internal ALB to backend containers (:8000)"
    protocol        = "tcp"
    from_port       = 8000
    to_port         = 8000
    security_groups = [aws_security_group.backend_alb.id, aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/${var.environment}-mercado-backend"
  retention_in_days = 7
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "frontend" {
  name              = "/ecs/${var.environment}-mercado-frontend"
  retention_in_days = 7
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "scraper" {
  name              = "/ecs/${var.environment}-mercado-scraper"
  retention_in_days = 7
  tags              = local.common_tags
}

# Backend Task Definition
resource "aws_ecs_task_definition" "backend" {
  family                   = "${var.environment}-mercado-backend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = data.aws_iam_role.lab_role.arn
  task_role_arn            = data.aws_iam_role.lab_role.arn

  container_definitions = jsonencode([
    {
      name  = "backend"
      image = var.backend_image      # ⬅ the immutable tag
      essential = true
      
      portMappings = [
        {
          containerPort = 8000
          protocol      = "tcp"
        }
      ]
      
      environment = [
        {
          name  = "DATABASE_URL"
          value = var.database_url
        },
        {
          name  = "PYTHONUNBUFFERED"
          value = "1"
        },
        {
          name  = "SCRAPER_URL"
          value = "http://mercado-scraper:8001" # ECS service DNS inside cluster
        },
        {
          name  = "COGNITO_POOL_ID"
          value = var.cognito_pool_id
        },
        {
          name  = "COGNITO_CLIENT_ID"
          value = var.cognito_client_id
        },
        {
          name  = "COGNITO_REGION"
          value = var.aws_region
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.backend.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

# Frontend Task Definition
resource "aws_ecs_task_definition" "frontend" {
  family                   = "${var.environment}-mercado-frontend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu    = 256
  memory = 512
  execution_role_arn = data.aws_iam_role.lab_role.arn
  task_role_arn      = data.aws_iam_role.lab_role.arn

  container_definitions = jsonencode([
    {
      name  = "frontend"
      image = var.frontend_image      # ⬅ the immutable tag
      essential = true

      portMappings = [{ containerPort = 80 }]

      environment = [
        {
          name  = "VITE_API_URL"
          value = "/api"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.frontend.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_task_definition" "scraper_task" {
  family                   = "${var.environment}-mercado-scraper-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = data.aws_iam_role.lab_role.arn
  task_role_arn            = data.aws_iam_role.lab_role.arn

  container_definitions = jsonencode([
    {
      name  = "mercado-scraper"
      image = var.scraper_image
      essential = true
      portMappings = [
        {
          containerPort = 8001
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "DATABASE_URL"
          value = var.database_url
        },
        {
          name  = "PYTHONUNBUFFERED"
          value = "1"
        },
        {
          name  = "SQS_QUEUE_URL"
          value = var.sqs_queue_url
        },
        {
          name  = "SQS_REGION"
          value = var.sqs_region
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.scraper.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}




# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.environment}-mercado-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets           = var.public_subnet_ids

  tags = merge(local.common_tags, {
    Name = "${var.environment}-mercado-alb"
  })
}

# ALB Security Group
resource "aws_security_group" "alb" {
  name        = "${var.environment}-mercado-alb"
  description = "Security group for ALB"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Removed public access to :8000 – backend is now internal only

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.environment}-mercado-alb"
  })
}

# Target Group (backend only)
resource "aws_lb_target_group" "backend" {
  name        = "${var.environment}-mercado-backend-tg"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 5
    timeout             = 15
    interval            = 60
    path                = "/health"
    matcher             = "200"
  }

  tags = local.common_tags
}

resource "aws_lb_target_group" "frontend" {
  name        = "${var.environment}-mercado-frontend-tg"
  port        = 80    # Updated to match ECR build task definition
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/"
    matcher             = "200"
  }

  tags = local.common_tags
}

# ALB Listeners
resource "aws_lb_listener" "frontend" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

# --- New Target Group for internal ALB (used by public ALB rule) ---
resource "aws_lb_target_group" "backend_internal_alb" {
  name        = "${var.environment}-backend-alb-tg"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "alb"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 5
    timeout             = 15
    interval            = 60
    path                = "/health"
    matcher             = "200"
  }

  tags = local.common_tags
}

# Attach the internal ALB as a target in the new TG
resource "aws_lb_target_group_attachment" "backend_alb_attachment" {
  target_group_arn = aws_lb_target_group.backend_internal_alb.arn
  target_id        = aws_lb.backend_alb.arn
  port             = 8000
}

# --- Update api_proxy rule to forward to the new TG ---
resource "aws_lb_listener_rule" "api_proxy" {
  listener_arn = aws_lb_listener.frontend.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_internal_alb.arn
  }

  condition {
    path_pattern { values = ["/api/*"] }
  }
}

# ECS Services with count meta-argument
resource "aws_ecs_service" "backend" {
  count           = var.backend_replicas > 0 ? 1 : 0
  name            = "${var.environment}-mercado-backend-service"
  cluster         = aws_ecs_cluster.mercado_cluster.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = var.backend_replicas
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id, var.db_access_sg_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend.arn
    container_name   = "backend"
    container_port   = 8000
  }

  health_check_grace_period_seconds = 1800   # 30 min

  depends_on = [aws_lb_listener.backend_internal]

  tags = local.common_tags
}

resource "aws_ecs_service" "frontend" {
  count           = var.frontend_replicas > 0 ? 1 : 0
  name            = "${var.environment}-mercado-frontend-service"
  cluster         = aws_ecs_cluster.mercado_cluster.id
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = var.frontend_replicas
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.public_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend.arn
    container_name   = "frontend"
    container_port   = 80   # Updated to match ECR build task definition
  }

  depends_on = [aws_lb_listener.frontend]

  tags = local.common_tags
} 

resource "aws_ecs_service" "scraper" {
  count           = var.scraper_replicas > 0 ? 1 : 0
  name            = "${var.environment}-mercado-scraper-service"
  cluster         = aws_ecs_cluster.mercado_cluster.id
  task_definition = aws_ecs_task_definition.scraper_task.arn
  desired_count   = var.scraper_replicas
  capacity_provider_strategy {
  capacity_provider = "FARGATE_SPOT"
  weight            = 1        # 100 % Spot
  base              = 0
}

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id, var.db_access_sg_id]
    assign_public_ip = false
  }

  # No external load balancer needed if the scraper just communicates with RDS
}

# New Security Group for internal backend ALB
resource "aws_security_group" "backend_alb" {
  name        = "${var.environment}-mercado-backend-alb"
  description = "Security group for internal backend ALB"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow traffic from public ALB SG on :8000"
    protocol        = "tcp"
    from_port       = 8000
    to_port         = 8000
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

# Internal Backend ALB
resource "aws_lb" "backend_alb" {
  name               = "${var.environment}-backend-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.backend_alb.id]
  subnets            = var.private_subnet_ids
  tags               = local.common_tags
}

# Listener for internal backend ALB
resource "aws_lb_listener" "backend_internal" {
  load_balancer_arn = aws_lb.backend_alb.arn
  port              = "8000"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}

# Outputs
output "backend_alb_dns_name" {
  description = "DNS name of the internal backend ALB"
  value       = aws_lb.backend_alb.dns_name
}