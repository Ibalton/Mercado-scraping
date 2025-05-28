# ECR Repositories for container images
resource "aws_ecr_repository" "backend" {
  name                 = "${var.project_name}-backend-${var.environment}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "${var.project_name}-backend-ecr-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_ecr_repository" "frontend" {
  name                 = "${var.project_name}-frontend-${var.environment}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "${var.project_name}-frontend-ecr-${var.environment}"
    Environment = var.environment
  }
}

# S3 bucket for storing application code
resource "aws_s3_bucket" "app_code" {
  bucket = "${var.project_name}-app-code-${var.environment}-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "${var.project_name}-app-code-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "app_code" {
  bucket = aws_s3_bucket.app_code.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Upload backend code to S3
resource "aws_s3_object" "backend_code" {
  bucket = aws_s3_bucket.app_code.id
  key    = "backend/main.py"
  source = "../backend/main.py"
  etag   = filemd5("../backend/main.py")
}

resource "aws_s3_object" "backend_api" {
  bucket = aws_s3_bucket.app_code.id
  key    = "backend/api.py"
  source = "../backend/api.py"
  etag   = filemd5("../backend/api.py")
}

resource "aws_s3_object" "backend_models" {
  bucket = aws_s3_bucket.app_code.id
  key    = "backend/models.py"
  source = "../backend/models.py"
  etag   = filemd5("../backend/models.py")
}

# Policy to allow ECS tasks to access S3
resource "aws_iam_role_policy" "ecs_task_s3" {
  name = "${var.project_name}-ecs-task-s3-${var.environment}"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.app_code.arn,
          "${aws_s3_bucket.app_code.arn}/*"
        ]
      }
    ]
  })
}

# Updated Backend Task Definition with code download
resource "aws_ecs_task_definition" "backend_with_code" {
  family                   = "${var.project_name}-backend-code-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.backend_cpu
  memory                   = var.backend_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn           = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name  = "backend"
      image = "python:3.11-slim"
      
      command = [
        "/bin/sh",
        "-c",
        "apt-get update && apt-get install -y awscli && aws s3 cp s3://${aws_s3_bucket.app_code.id}/backend/ /app/ --recursive && pip install --no-cache-dir sentence_transformers sqlacodegen psycopg2-binary pgvector aiohttp beautifulsoup4 pandas python-dotenv fastapi uvicorn && uvicorn main:app --host 0.0.0.0 --port ${var.backend_port}"
      ]

      workingDirectory = "/app"
      
      environment = [
        {
          name  = "DATABASE_URL"
          value = "postgres://${var.db_username}:${var.db_password}@${aws_db_instance.postgres.endpoint}/${var.db_name}"
        },
        {
          name  = "AWS_DEFAULT_REGION"
          value = var.aws_region
        }
      ]

      portMappings = [
        {
          containerPort = var.backend_port
          protocol      = "tcp"
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

      essential = true
    }
  ])

  tags = {
    Name        = "${var.project_name}-backend-task-code-${var.environment}"
    Environment = var.environment
  }
} 