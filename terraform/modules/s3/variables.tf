variable "vite_build_folder" {
  type        = string
  description = "Path to the Vite build output folder"
  default     = "./dist"
}


variable "vite_api_url" {
    type        = string
    description = "API URL to be used in the Vite build"
    validation {
        condition     = can(regex("https?://", var.vite_api_url))
        error_message = "Vite API URL must start with http:// or https://"
    }
}

variable "vite_cognito_pool_id" {
    type        = string
    description = "Cognito User Pool ID for authentication"
}
variable "vite_cognito_client_id" {
    type        = string
    description = "Cognito Client ID for authentication"
}
variable "vite_cognito_region" {
    type        = string
    description = "AWS region for Cognito"  
}

variable "vite_cognito_domain" {
    type        = string
    description = "Cognito domain for authentication"
}

variable "vite_cognito_redirect_uri" {
    type        = string
    description = "Cognito redirect URI after authentication"
}

variable "vite_cognito_logout_uri" {
    type        = string
    description = "Cognito logout URI"
}

variable "bucket_name" {
  description = "Name of the S3 bucket for Vite static site"
  type        = string
  default = ""
}