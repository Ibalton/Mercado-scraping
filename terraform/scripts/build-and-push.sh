#!/bin/bash

# Script to build and push Docker images to ECR
# Usage: ./build-and-push.sh

set -e

# Get AWS account ID and region
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(aws configure get region)

# ECR repository names
BACKEND_REPO="mercado-scraping-backend-dev"
FRONTEND_REPO="mercado-scraping-frontend-dev"

# ECR URLs
BACKEND_ECR_URL="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$BACKEND_REPO"
FRONTEND_ECR_URL="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$FRONTEND_REPO"

echo "Building and pushing Docker images to ECR..."
echo "AWS Account ID: $AWS_ACCOUNT_ID"
echo "AWS Region: $AWS_REGION"

# Login to ECR
echo "Logging in to ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Build and push backend
echo "Building backend image..."
cd ../../backend
docker build -t $BACKEND_REPO:latest .
docker tag $BACKEND_REPO:latest $BACKEND_ECR_URL:latest
echo "Pushing backend image..."
docker push $BACKEND_ECR_URL:latest

# Build and push frontend
echo "Building frontend image..."
cd ../frontend
docker build -t $FRONTEND_REPO:latest .
docker tag $FRONTEND_REPO:latest $FRONTEND_ECR_URL:latest
echo "Pushing frontend image..."
docker push $FRONTEND_ECR_URL:latest

echo "Docker images built and pushed successfully!"
echo "Backend image: $BACKEND_ECR_URL:latest"
echo "Frontend image: $FRONTEND_ECR_URL:latest" 