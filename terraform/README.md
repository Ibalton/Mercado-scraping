# Mercado Scraping - AWS ECS Terraform Deployment

This Terraform configuration deploys the Mercado Scraping application to AWS ECS with RDS PostgreSQL database.

## Architecture Overview

The deployment creates the following AWS resources:

- **VPC** with public and private subnets across 2 availability zones
- **RDS PostgreSQL** instance (with pgvector extension support) in private subnets
- **ECS Fargate** cluster running backend and frontend services
- **Application Load Balancer** for routing traffic
- **ECR repositories** for container images
- **S3 bucket** for application code storage

## Prerequisites

1. AWS CLI configured with appropriate credentials
2. Terraform installed (version >= 1.0)
3. Docker installed (for building images)
4. PostgreSQL client (for database initialization)

## AWS Learner Lab Considerations

Since AWS Learner Lab has IAM restrictions, this configuration:
- Uses standard AWS-managed policies where possible
- Minimizes custom IAM role creation
- Uses Fargate instead of EC2 to avoid instance profile issues

## Deployment Steps

### 1. Prepare Configuration

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values, especially the database password
```

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Plan the Deployment

```bash
terraform plan
```

### 4. Apply the Configuration

```bash
terraform apply
```

### 5. Build and Push Docker Images (Optional)

If you want to use custom Docker images instead of the standard AWS images:

```bash
chmod +x scripts/build-and-push.sh
./scripts/build-and-push.sh
```

Then update the task definitions in `ecs.tf` to use your ECR image URLs.

### 6. Initialize the Database

After the RDS instance is created:

```bash
# Get the RDS endpoint from Terraform output
terraform output rds_endpoint

# Initialize the database
chmod +x scripts/init-db.sh
./scripts/init-db.sh <rds-endpoint> cloud postgres <your-password> ../backend/db_dump.sql
```

### 7. Update ECS Services

If you need to update the ECS services with new task definitions:

```bash
aws ecs update-service --cluster mercado-scraping-cluster-dev --service mercado-scraping-backend-dev --force-new-deployment
aws ecs update-service --cluster mercado-scraping-cluster-dev --service mercado-scraping-frontend-dev --force-new-deployment
```

## Accessing the Application

After deployment, get the ALB URL:

```bash
terraform output alb_url
```

The application will be available at:
- Frontend: `http://<alb-dns-name>/`
- Backend API: `http://<alb-dns-name>/api/`

## Cost Optimization

To minimize costs in AWS Learner Lab:
- The configuration uses minimal resources (t3.micro for RDS, minimal Fargate resources)
- NAT Gateways are included for private subnet internet access (can be removed if not needed)
- Set `desired_count = 0` in terraform.tfvars to stop ECS tasks when not in use

## Troubleshooting

### ECS Tasks Not Starting
- Check CloudWatch logs: `/ecs/mercado-scraping-backend-dev` and `/ecs/mercado-scraping-frontend-dev`
- Verify security groups allow traffic between ALB and ECS tasks
- Ensure RDS security group allows connections from ECS tasks

### Database Connection Issues
- Verify RDS endpoint is correct in ECS task environment variables
- Check RDS security group allows port 5432 from ECS tasks
- Ensure pgvector extension is installed: `CREATE EXTENSION IF NOT EXISTS vector;`

### Application Code Not Loading
- Verify S3 bucket has the application files
- Check ECS task role has permissions to read from S3
- Review CloudWatch logs for any errors during code download

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

**Note**: This will delete all resources including the RDS database. Make sure to backup any important data first.

## File Structure

```
terraform/
├── main.tf              # Provider and data sources
├── variables.tf         # Input variables
├── outputs.tf          # Output values
├── network.tf          # VPC, subnets, security groups
├── rds.tf              # RDS PostgreSQL database
├── ecs.tf              # ECS cluster, task definitions, services
├── ecs-simplified.tf   # Alternative ECS configuration with S3 code storage
├── alb.tf              # Application Load Balancer
├── terraform.tfvars.example  # Example variables file
├── scripts/
│   ├── init-db.sh      # Database initialization script
│   └── build-and-push.sh  # Docker build and push script
└── README.md           # This file
```

## Security Considerations

1. **Database Password**: Use a strong password and consider using AWS Secrets Manager
2. **Network Security**: The configuration uses private subnets for ECS tasks and RDS
3. **Encryption**: RDS storage encryption is enabled by default
4. **Logging**: CloudWatch logs are configured for monitoring

## Next Steps

1. Set up CI/CD pipeline for automated deployments
2. Configure auto-scaling for ECS services based on load
3. Add HTTPS support with ACM certificate
4. Implement backup strategy for RDS
5. Set up monitoring and alerting with CloudWatch 