#!/bin/bash

# Test database connectivity from EKS pods
# This script helps verify network connectivity between EKS and RDS

set -e

RDS_ENDPOINT="${1:-}"
ENVIRONMENT="${2:-dev}"

if [ -z "$RDS_ENDPOINT" ]; then
    echo "Error: RDS endpoint not provided"
    echo "Usage: $0 <rds-endpoint> [environment]"
    echo "Example: $0 rds-platform-dev-postgres.xxxxxx.us-east-1.rds.amazonaws.com dev"
    exit 1
fi

echo "=========================================="
echo "RDS Connectivity Test"
echo "RDS Endpoint: $RDS_ENDPOINT"
echo "Environment: $ENVIRONMENT"
echo "=========================================="
echo ""

# Test 1: DNS Resolution
echo "[1/5] Testing DNS resolution..."
if nslookup "$RDS_ENDPOINT" > /dev/null 2>&1; then
    echo "✓ DNS resolution successful"
    IP_ADDRESS=$(nslookup "$RDS_ENDPOINT" | grep "Address:" | tail -1 | awk '{print $2}')
    echo "  Resolved to: $IP_ADDRESS"
else
    echo "✗ DNS resolution failed"
    exit 1
fi

# Test 2: Port Connectivity
echo ""
echo "[2/5] Testing port connectivity..."
if nc -zv "$RDS_ENDPOINT" 5432 2>&1 | grep -q "succeeded"; then
    echo "✓ Port 5432 is reachable"
else
    echo "✗ Port 5432 is not reachable"
    echo "  Check security group rules and network ACLs"
    exit 1
fi

# Test 3: SSL/TLS Connection
echo ""
echo "[3/5] Testing SSL/TLS connection..."
if timeout 5 openssl s_client -connect "${RDS_ENDPOINT}:5432" -starttls postgres < /dev/null 2>&1 | grep -q "Verify return code: 0"; then
    echo "✓ SSL/TLS connection successful"
else
    echo "⚠ SSL/TLS verification may have issues (check certificates)"
fi

# Test 4: PostgreSQL Protocol Test
echo ""
echo "[4/5] Testing PostgreSQL protocol..."
if command -v psql &> /dev/null; then
    echo "Enter master password (or Ctrl+C to skip):"
    if psql -h "$RDS_ENDPOINT" -U postgres -d postgres -c "SELECT version();" 2>&1 | grep -q "PostgreSQL"; then
        echo "✓ PostgreSQL connection successful"
    else
        echo "⚠ PostgreSQL connection failed (authentication or network issue)"
    fi
else
    echo "⚠ psql not installed, skipping PostgreSQL protocol test"
fi

# Test 5: Fetch from Secrets Manager and Test
echo ""
echo "[5/5] Testing with credentials from Secrets Manager..."

if command -v aws &> /dev/null; then
    # Get customer service credentials
    SECRET_JSON=$(aws secretsmanager get-secret-value \
        --secret-id "rds/${ENVIRONMENT}/customer-service" \
        --region us-east-1 \
        --query 'SecretString' \
        --output text 2>/dev/null || echo "")
    
    if [ ! -z "$SECRET_JSON" ]; then
        USERNAME=$(echo "$SECRET_JSON" | jq -r '.username')
        PASSWORD=$(echo "$SECRET_JSON" | jq -r '.password')
        DATABASE=$(echo "$SECRET_JSON" | jq -r '.database')
        
        if command -v psql &> /dev/null; then
            export PGPASSWORD="$PASSWORD"
            if psql -h "$RDS_ENDPOINT" -U "$USERNAME" -d "$DATABASE" -c "SELECT 1;" > /dev/null 2>&1; then
                echo "✓ Connection successful with customer-service credentials"
            else
                echo "✗ Connection failed with customer-service credentials"
            fi
            unset PGPASSWORD
        fi
    else
        echo "⚠ Could not fetch credentials from Secrets Manager"
    fi
else
    echo "⚠ AWS CLI not installed, skipping Secrets Manager test"
fi

echo ""
echo "=========================================="
echo "Connectivity Test Summary"
echo "=========================================="
echo "RDS Endpoint: $RDS_ENDPOINT"
echo "Port 5432: Reachable"
echo "DNS Resolution: Success"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Initialize databases: cd sql && ./execute-init.sh $RDS_ENDPOINT"
echo "2. Deploy Kubernetes secrets: kubectl apply -f kubernetes/external-secrets/"
echo "3. Deploy ConfigMaps: kubectl apply -f kubernetes/configmaps/"
echo "=========================================="
