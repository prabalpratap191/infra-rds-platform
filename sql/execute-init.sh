#!/bin/bash

# Script to execute database initialization
# This script fetches passwords from AWS Secrets Manager and executes the SQL script

set -e

# Configuration
ENVIRONMENT="dev"
REGION="us-east-1"
RDS_ENDPOINT="${1:-}"

if [ -z "$RDS_ENDPOINT" ]; then
    echo "Error: RDS endpoint not provided"
    echo "Usage: $0 <rds-endpoint>"
    echo "Example: $0 rds-platform-dev-postgres.xxxxxxxxxx.us-east-1.rds.amazonaws.com"
    exit 1
fi

echo "==============================================="
echo "RDS Database Initialization Script"
echo "Environment: $ENVIRONMENT"
echo "Region: $REGION"
echo "RDS Endpoint: $RDS_ENDPOINT"
echo "==============================================="

# Fetch master password from Secrets Manager
echo "Fetching master credentials from Secrets Manager..."
MASTER_SECRET=$(aws secretsmanager get-secret-value \
    --secret-id "rds/${ENVIRONMENT}/master-credentials" \
    --region "$REGION" \
    --query 'SecretString' \
    --output text)

MASTER_PASSWORD=$(echo "$MASTER_SECRET" | jq -r '.password')

if [ -z "$MASTER_PASSWORD" ]; then
    echo "Error: Failed to fetch master password"
    exit 1
fi

echo "Master credentials retrieved successfully"

# Fetch microservice passwords
echo "Fetching microservice credentials..."

declare -A PASSWORDS
for service in customer-service order-service catalog-service order-history-service notification-service; do
    echo "  Fetching credentials for $service..."
    SECRET=$(aws secretsmanager get-secret-value \
        --secret-id "rds/${ENVIRONMENT}/${service}" \
        --region "$REGION" \
        --query 'SecretString' \
        --output text)
    
    PASSWORD=$(echo "$SECRET" | jq -r '.password')
    PASSWORDS[$service]=$PASSWORD
done

echo "All credentials retrieved successfully"

# Create temporary SQL file with actual passwords
echo "Creating temporary SQL file with credentials..."
TEMP_SQL=$(mktemp)
cp init-databases.sql "$TEMP_SQL"

# Replace placeholders with actual passwords
sed -i "s/REPLACE_WITH_SECRET_VALUE/${PASSWORDS[customer-service]}/" "$TEMP_SQL"
sed -i "s/REPLACE_WITH_SECRET_VALUE/${PASSWORDS[order-service]}/" "$TEMP_SQL"
sed -i "s/REPLACE_WITH_SECRET_VALUE/${PASSWORDS[catalog-service]}/" "$TEMP_SQL"
sed -i "s/REPLACE_WITH_SECRET_VALUE/${PASSWORDS[order-history-service]}/" "$TEMP_SQL"
sed -i "s/REPLACE_WITH_SECRET_VALUE/${PASSWORDS[notification-service]}/" "$TEMP_SQL"

echo "Executing database initialization..."
export PGPASSWORD="$MASTER_PASSWORD"

psql -h "$RDS_ENDPOINT" \
     -U postgres \
     -d postgres \
     -f "$TEMP_SQL" \
     --echo-errors

if [ $? -eq 0 ]; then
    echo "==============================================="
    echo "Database initialization completed successfully!"
    echo "==============================================="
    echo ""
    echo "Created databases:"
    echo "  - customer_db (user: customer_user)"
    echo "  - order_db (user: order_user)"
    echo "  - catalog_db (user: catalog_user)"
    echo "  - order_history_db (user: order_history_user)"
    echo "  - notification_db (user: notification_user)"
    echo ""
    echo "All passwords are stored in AWS Secrets Manager"
else
    echo "Error: Database initialization failed"
    exit 1
fi

# Clean up temporary file
rm -f "$TEMP_SQL"
unset PGPASSWORD

echo "Cleanup completed"
