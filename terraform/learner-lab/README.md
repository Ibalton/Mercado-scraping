# AWS Learner Lab - Simplified ECS Deployment

This is a simplified version of the Terraform configuration specifically designed for AWS Learner Lab environments with limited IAM permissions.

## Features

- Uses default VPC to avoid networking complexity
- Minimal IAM role creation
- Uses public AWS container images as base
- Simplified security groups
- Basic RDS PostgreSQL setup

## Quick Start

1. **Initialize Terraform**
   ```bash
   cd terraform/learner-lab
   terraform init
   ```

2. **Deploy Infrastructure**
   ```bash
   terraform apply
   ```

3. **Get Application URL**
   ```bash
   terraform output alb_url
   ```

## What Gets Deployed

- **ECS Cluster**: Running on Fargate
- **ALB**: Application Load Balancer for routing
- **RDS PostgreSQL**: Database instance (db.t3.micro)
- **ECS Services**: Backend (FastAPI) and Frontend (Nginx)

## Post-Deployment Steps

1. **Initialize Database**
   ```bash
   # Get RDS endpoint
   terraform output rds_endpoint
   
   # Connect and create pgvector extension
   psql -h <rds-host> -U postgres -d cloud
   CREATE EXTENSION IF NOT EXISTS vector;
   \q
   
   # Import data
   psql -h <rds-host> -U postgres -d cloud < ../../backend/db_dump.sql
   ```

2. **Update Task Definitions**
   - The current setup uses placeholder applications
   - Update the task definitions in `ecs-simple.tf` to use your actual application code
   - Consider building custom Docker images and pushing to ECR

## Limitations

- Uses default VPC (no custom networking)
- Public IP assignment for ECS tasks
- Basic security group rules
- No auto-scaling configured
- Placeholder applications (update needed)

## Cost Optimization

- Uses minimal resources (256 CPU, 512 MB memory)
- db.t3.micro for RDS (free tier eligible)
- Set desired_count to 0 when not in use

## Troubleshooting

1. **IAM Permission Errors**
   - This configuration uses minimal IAM roles
   - If you still get errors, check AWS Learner Lab documentation

2. **ECS Tasks Not Starting**
   - Check CloudWatch logs: `/ecs/mercado-scraping`
   - Verify security groups allow traffic

3. **Database Connection Issues**
   - Ensure RDS security group allows connections from ECS
   - Check database credentials in task definition

## Clean Up

```bash
terraform destroy
```

This will remove all created resources. 