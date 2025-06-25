# Cognito set up


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

  tags = var.default_tags
}

resource "aws_cognito_user_pool_client" "spa" {
  name         = "mercado-scraper-spa-client"
  user_pool_id = aws_cognito_user_pool.mercado.id

  generate_secret              = false # SPA / public client
  explicit_auth_flows          = ["ALLOW_USER_PASSWORD_AUTH", "ALLOW_REFRESH_TOKEN_AUTH", "ALLOW_USER_SRP_AUTH", "ALLOW_CUSTOM_AUTH"]
  supported_identity_providers = ["COGNITO"]
 #Workaround lambda 
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
