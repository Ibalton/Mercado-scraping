#!/bin/bash

# Script to initialize RDS database with dump file
# Usage: ./init-db.sh <rds-endpoint> <db-name> <username> <password> <dump-file>

RDS_ENDPOINT=$1
DB_NAME=$2
DB_USER=$3
DB_PASSWORD=$4
DUMP_FILE=$5

if [ -z "$RDS_ENDPOINT" ] || [ -z "$DB_NAME" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASSWORD" ] || [ -z "$DUMP_FILE" ]; then
    echo "Usage: $0 <rds-endpoint> <db-name> <username> <password> <dump-file>"
    exit 1
fi

# Extract host and port from endpoint
DB_HOST=$(echo $RDS_ENDPOINT | cut -d: -f1)
DB_PORT=$(echo $RDS_ENDPOINT | cut -d: -f2)

echo "Initializing database..."
echo "Host: $DB_HOST"
echo "Port: $DB_PORT"
echo "Database: $DB_NAME"

# First, install pgvector extension
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "CREATE EXTENSION IF NOT EXISTS vector;"

# Then restore the dump
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME < $DUMP_FILE

echo "Database initialization complete!" 