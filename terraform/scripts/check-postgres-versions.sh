#!/bin/bash

# Script to check available PostgreSQL versions in your AWS region
# Usage: ./check-postgres-versions.sh

echo "Checking available PostgreSQL versions in your AWS region..."

# Get current AWS region
REGION=$(aws configure get region)
if [ -z "$REGION" ]; then
    REGION="us-east-1"
    echo "No region configured, using default: $REGION"
else
    echo "Current region: $REGION"
fi

echo ""
echo "Available PostgreSQL versions:"
echo "================================"

# Get available PostgreSQL versions
aws rds describe-db-engine-versions \
    --engine postgres \
    --query 'DBEngineVersions[?contains(SupportedEngineModes, `provisioned`)].{Version:EngineVersion,Description:DBEngineVersionDescription}' \
    --output table \
    --region $REGION

echo ""
echo "Recommended versions for pgvector support:"
echo "- PostgreSQL 15.x (best compatibility)"
echo "- PostgreSQL 14.x (also supported)"
echo ""
echo "To use a specific version, update the engine_version in your Terraform configuration." 