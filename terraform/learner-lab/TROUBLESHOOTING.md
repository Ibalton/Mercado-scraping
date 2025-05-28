# AWS Learner Lab Troubleshooting Guide

## PostgreSQL Version Error

**Error**: `Cannot find version X.X for postgres`

**Solution**:
1. Check available PostgreSQL versions in your region:
   ```bash
   aws rds describe-db-engine-versions --engine postgres --query 'DBEngineVersions[].EngineVersion' --output table
   ```

2. Update `terraform.tfvars` with an available version:
   ```hcl
   postgres_version = "14.12"  # or whatever version is available
   ```

3. Common working versions:
   - `15.7`, `15.6`, `15.5`
   - `14.12`, `14.11`, `14.10`
   - `13.15`, `13.14`, `13.13`

## IAM Permission Errors

**Error**: `User: arn:aws:sts::xxx:assumed-role/xxx is not authorized to perform: xxx`

**Solutions**:
- AWS Learner Lab has limited permissions
- Try using the simplified configuration in `learner-lab/` folder
- Some resources may not be available in Learner Lab

## ECS Task Startup Issues

**Error**: Tasks keep stopping or failing to start

**Check**:
1. CloudWatch logs: `/ecs/mercado-scraping`
2. Security groups allow traffic
3. Container images are accessible

**Common fixes**:
- Ensure public IP assignment is enabled for ECS tasks
- Check that the container commands are valid
- Verify memory/CPU limits are sufficient

## Database Connection Issues

**Error**: Cannot connect to RDS from ECS

**Check**:
1. Security groups allow port 5432 between ECS and RDS
2. RDS is in the same VPC as ECS tasks
3. Database credentials are correct

## Resource Limits

**Error**: Resource limit exceeded

**Solutions**:
- AWS Learner Lab has resource limits
- Destroy unused resources: `terraform destroy`
- Use minimal instance sizes (t3.micro, etc.)

## Quick Commands

```bash
# Check available PostgreSQL versions
aws rds describe-db-engine-versions --engine postgres --query 'DBEngineVersions[].EngineVersion' --output table

# Check ECS service status
aws ecs describe-services --cluster mercado-scraping-cluster --services mercado-scraping-backend mercado-scraping-frontend

# View ECS task logs
aws logs describe-log-streams --log-group-name /ecs/mercado-scraping

# Force new ECS deployment
aws ecs update-service --cluster mercado-scraping-cluster --service mercado-scraping-backend --force-new-deployment
``` 