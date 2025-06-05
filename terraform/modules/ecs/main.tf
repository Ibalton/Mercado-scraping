# ECS Cluster


resource "aws_ecs_cluster" "mercado_cluster" {
  name = "mercado-scraper-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "mercado-scraper-cluster"
  }
}

# Use existing IAM roles from AWS Learner Lab
# Note: AWS Learner Lab provides pre-created roles that we can reference
data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

# Security Group for ECS Tasks
resource "aws_security_group" "ecs_tasks" {
  name        = "mercado-ecs-tasks"
  description = "Security group for ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Backend API"
  }

  ingress {
    from_port   = 5173
    to_port     = 5173
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Frontend"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "mercado-ecs-tasks"
  }
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/mercado-backend"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "frontend" {
  name              = "/ecs/mercado-frontend"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "scraper" {
  name              = "/ecs/mercado-scraper"
  retention_in_days = 7
}

# Backend Task Definition
resource "aws_ecs_task_definition" "backend" {
  family                   = "mercado-backend"
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
  family                   = "mercado-frontend"
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
          value = "http://${aws_lb.main.dns_name}:8000"   # runtime value
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
  family                   = "mercado-scraper-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = data.aws_iam_role.lab_role.arn   # <- No longer created
  task_role_arn            = data.aws_iam_role.lab_role.arn       

  container_definitions = jsonencode([
    {
      name      = "mercado-scraper"
      image     = var.scraper_image
      essential = true,
      environment = [
        {
          name  = "SQS_QUEUE_URL"
          value = var.sqs_queue_url
        },
        {
          name  = "SQS_REGION"
          value = var.sqs_region
        },
        {
          name  = "DATABASE_URL"
          value = var.database_url
        },
        {
          name  = "PYTHONUNBUFFERED"
          value = "1"
        }
      ],
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = aws_cloudwatch_log_group.scraper.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}


# Application Load Balancer
resource "aws_lb" "main" {
  name               = "mercado-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets           = var.public_subnet_ids

  tags = {
    Name = "mercado-alb"
  }
}

# ALB Security Group
resource "aws_security_group" "alb" {
  name        = "mercado-alb"
  description = "Security group for ALB"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "mercado-alb"
  }
}

# Target Groups
resource "aws_lb_target_group" "backend" {
  name        = "mercado-backend-tg"
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
}

resource "aws_lb_target_group" "frontend" {
  name        = "mercado-frontend-tg"
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

resource "aws_lb_listener" "backend" {
  load_balancer_arn = aws_lb.main.arn
  port              = "8000"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}

# ECS Services
resource "aws_ecs_service" "backend" {
  name            = "mercado-backend-service"
  cluster         = aws_ecs_cluster.mercado_cluster.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend.arn
    container_name   = "backend"
    container_port   = 8000
  }

  health_check_grace_period_seconds = 1800   # 30 min

  depends_on = [aws_lb_listener.backend]
}

resource "aws_ecs_service" "frontend" {
  name            = "mercado-frontend-service"
  cluster         = aws_ecs_cluster.mercado_cluster.id
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = 1
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
} 


resource "aws_ecs_service" "scraper" {
  name            = "mercado-scraper-service"
  cluster         = aws_ecs_cluster.mercado_cluster.id
  task_definition = aws_ecs_task_definition.scraper_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  # No external load balancer needed if the scraper just communicates with RDS
}