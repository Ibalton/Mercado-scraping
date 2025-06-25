# Null resource to install Python dependencies into /build folder
resource "null_resource" "install_dependencies" {
  provisioner "local-exec" {
    command = "docker run --rm -v ${abspath(var.lambda_root)}:/lambda -w /lambda python:3.12-slim sh install.sh"
  }

  triggers = {
    requirements_hash = filemd5("${var.lambda_root}/requirements.txt")
    main_hash         = filemd5("${var.lambda_root}/main.py")
    install_hash      = filemd5("${var.lambda_root}/install.sh")
  }
}

# UUID to force archive rebuild
resource "random_uuid" "lambda_src_hash" {
  keepers = {
    for filename in setunion(
      fileset(var.lambda_root, "main.py"),
      fileset(var.lambda_root, "requirements.txt")
    ) :
    filename => filemd5("${var.lambda_root}/${filename}")
  }
}

# Create zip for Lambda function
data "archive_file" "lambda_source" {
  depends_on  = [null_resource.install_dependencies]
  type        = "zip"
  source_dir  = "${var.lambda_root}/build"
  output_path = "${path.module}/${random_uuid.lambda_src_hash.result}.zip"
}

# IAM Role (assumes LabRole exists)
data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

# Log group for Lambda
resource "aws_cloudwatch_log_group" "task_creation" {
  name              = "/aws/lambda/callback"
  retention_in_days = 14
}

# Lambda deployment
resource "aws_lambda_function" "scraper_lambda" {
  function_name    = "scraper_callback_api"
  role             = data.aws_iam_role.lab_role.arn
  filename         = data.archive_file.lambda_source.output_path
  source_code_hash = data.archive_file.lambda_source.output_base64sha256

  handler = "main.lambda_handler"
  runtime = "python3.12"
  timeout = 60

  environment {
    variables = {
      COGNITO_CLIENT_ID     = var.cognito_client_id
      COGNITO_CLIENT_SECRET = var.cognito_client_secret
      REDIRECT_URI = "${aws_apigatewayv2_api.lambda_api.api_endpoint}/callback"

      COGNITO_DOMAIN        = var.cognito_domain
      FRONTEND_URL          = var.frontend_url
    }
  }

  vpc_config {
    subnet_ids         = var.lambda_subnet_ids
    security_group_ids = var.lambda_security_group_ids
  }

  depends_on = [aws_cloudwatch_log_group.task_creation]
}

# HTTP API Gateway setup
resource "aws_apigatewayv2_api" "lambda_api" {
  name          = "scraper_callback_api"
  protocol_type = "HTTP"
}

# Integration between API Gateway and Lambda
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                 = aws_apigatewayv2_api.lambda_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.scraper_lambda.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

# Route for GET /callback
resource "aws_apigatewayv2_route" "callback_route" {
  api_id    = aws_apigatewayv2_api.lambda_api.id
  route_key = "GET /callback"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# Deploy the API to $default stage (auto deploy)
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.lambda_api.id
  name        = "$default"
  auto_deploy = true
}

# Give API Gateway permission to invoke Lambda
resource "aws_lambda_permission" "allow_apigw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scraper_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.lambda_api.execution_arn}/*/*"
}

# Output the full callback URL
output "callback_url" {
  description = "The full URL of the /callback endpoint"
  value       = "${aws_apigatewayv2_api.lambda_api.api_endpoint}/callback"
}
