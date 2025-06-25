variable "lambda_root" {
  type        = string
  description = "Relative path to the source of the lambda"
  default     = "../lambda"
}

variable "lambda_subnet_ids" {
  description = "The subnet IDs for the Lambda function"
  type        = list(string)
}

variable "lambda_security_group_ids" {
  description = "The security group IDs for the Lambda function"
  type        = list(string)
}


variable "database_url" {
  description = "URL of the database"
  type        = string
}

variable "cognito_client_id" {
  description = "Cognito Client ID for authentication"
  type        = string
}
variable "cognito_client_secret" {
  description = "Cognito Client Secret for authentication"
  type        = string
}
variable "cognito_domain" {
  description = "Cognito domain for authentication"
  type        = string
}
variable "frontend_url" {
  description = "Frontend URL for the application"
  type        = string
}