# Terraform variables for AWS Learner Lab deployment
aws_region   = "us-east-1"
project_name = "mercado-scraping"

# Database configuration
db_username      = "postgres"
db_password      = "postgres123"  # Change this to a secure password
db_name          = "cloud"
postgres_version = "15.7"  # Try 14.12 or 13.15 if this doesn't work

# Note: If you get a PostgreSQL version error, run:
# aws rds describe-db-engine-versions --engine postgres --query 'DBEngineVersions[].EngineVersion' --output table
# Then update the postgres_version above with an available version 