#!/bin/bash

# RDS Deployment Verification Script
# Validates RDS instance, security groups, secrets, and network connectivity

set -e

ENVIRONMENT="${1:-dev}"
REGION="${2:-us-east-1}"

echo "=========================================="
echo "RDS Deployment Verification"
echo "Environment: $ENVIRONMENT"
echo "Region: $REGION"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASSED=0
FAILED=0

# Function to print status
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ $2${NC}"
        ((PASSED++))
    else
        echo -e "${RED}✗ $2${NC}"
        ((FAILED++))
    fi
}

print_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

# 1. Verify RDS Instance
print_info "Verifying RDS instance..."
RDS_INSTANCE="rds-platform-${ENVIRONMENT}-postgres"

RDS_STATUS=$(aws rds describe-db-instances \
    --db-instance-identifier "$RDS_INSTANCE" \
    --region "$REGION" \
    --query 'DBInstances[0].DBInstanceStatus' \
    --output text 2>/dev/null || echo "not-found")

if [ "$RDS_STATUS" == "available" ]; then
    print_status 0 "RDS instance is available"
    
    # Get RDS details
    RDS_ENDPOINT=$(aws rds describe-db-instances \
        --db-instance-identifier "$RDS_INSTANCE" \
        --region "$REGION" \
        --query 'DBInstances[0].Endpoint.Address' \
        --output text)
    
    RDS_ENGINE=$(aws rds describe-db-instances \
        --db-instance-identifier "$RDS_INSTANCE" \
        --region "$REGION" \
        --query 'DBInstances[0].EngineVersion' \
        --output text)
    
    echo "  Endpoint: $RDS_ENDPOINT"
    echo "  Engine Version: PostgreSQL $RDS_ENGINE"
else
    print_status 1 "RDS instance is not available (Status: $RDS_STATUS)"
fi

# 2. Verify Encryption
print_info "Verifying encryption settings..."
ENCRYPTION=$(aws rds describe-db-instances \
    --db-instance-identifier "$RDS_INSTANCE" \
    --region "$REGION" \
    --query 'DBInstances[0].StorageEncrypted' \
    --output text 2>/dev/null)

if [ "$ENCRYPTION" == "True" ]; then
    print_status 0 "Storage encryption is enabled"
else
    print_status 1 "Storage encryption is not enabled"
fi

# 3. Verify Multi-AZ Configuration
print_info "Verifying Multi-AZ configuration..."
MULTI_AZ=$(aws rds describe-db-instances \
    --db-instance-identifier "$RDS_INSTANCE" \
    --region "$REGION" \
    --query 'DBInstances[0].MultiAZ' \
    --output text 2>/dev/null)

if [ "$MULTI_AZ" == "True" ]; then
    print_status 0 "Multi-AZ is enabled"
else
    echo -e "${YELLOW}[WARN] Multi-AZ is disabled (OK for dev)${NC}"
fi

# 4. Verify Public Accessibility
print_info "Verifying public accessibility..."
PUBLIC=$(aws rds describe-db-instances \
    --db-instance-identifier "$RDS_INSTANCE" \
    --region "$REGION" \
    --query 'DBInstances[0].PubliclyAccessible' \
    --output text 2>/dev/null)

if [ "$PUBLIC" == "False" ]; then
    print_status 0 "RDS is not publicly accessible"
else
    print_status 1 "RDS is publicly accessible (security risk!)"
fi

# 5. Verify Backup Configuration
print_info "Verifying backup configuration..."
BACKUP_RETENTION=$(aws rds describe-db-instances \
    --db-instance-identifier "$RDS_INSTANCE" \
    --region "$REGION" \
    --query 'DBInstances[0].BackupRetentionPeriod' \
    --output text 2>/dev/null)

if [ "$BACKUP_RETENTION" -ge 7 ]; then
    print_status 0 "Backup retention is configured ($BACKUP_RETENTION days)"
else
    print_status 1 "Backup retention is too low ($BACKUP_RETENTION days)"
fi

# 6. Verify Security Groups
print_info "Verifying security groups..."
SG_ID=$(aws rds describe-db-instances \
    --db-instance-identifier "$RDS_INSTANCE" \
    --region "$REGION" \
    --query 'DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId' \
    --output text 2>/dev/null)

if [ ! -z "$SG_ID" ]; then
    print_status 0 "Security group attached: $SG_ID"
    
    # Verify security group rules
    SG_RULES=$(aws ec2 describe-security-groups \
        --group-ids "$SG_ID" \
        --region "$REGION" \
        --query 'SecurityGroups[0].IpPermissions' \
        --output json 2>/dev/null)
    
    if [ ! -z "$SG_RULES" ]; then
        print_status 0 "Security group rules are configured"
    else
        print_status 1 "No security group rules found"
    fi
else
    print_status 1 "No security group attached"
fi

# 7. Verify Secrets Manager
print_info "Verifying Secrets Manager..."

SERVICES=("customer-service" "order-service" "catalog-service" "order-history-service" "notification-service")
SECRETS_OK=0

for service in "${SERVICES[@]}"; do
    SECRET_ARN=$(aws secretsmanager describe-secret \
        --secret-id "rds/${ENVIRONMENT}/${service}" \
        --region "$REGION" \
        --query 'ARN' \
        --output text 2>/dev/null || echo "")
    
    if [ ! -z "$SECRET_ARN" ]; then
        ((SECRETS_OK++))
    fi
done

if [ $SECRETS_OK -eq ${#SERVICES[@]} ]; then
    print_status 0 "All microservice secrets exist ($SECRETS_OK/${#SERVICES[@]})"
else
    print_status 1 "Some secrets are missing ($SECRETS_OK/${#SERVICES[@]})"
fi

# 8. Verify Master Secret
MASTER_SECRET=$(aws secretsmanager describe-secret \
    --secret-id "rds/${ENVIRONMENT}/master-credentials" \
    --region "$REGION" \
    --query 'ARN' \
    --output text 2>/dev/null || echo "")

if [ ! -z "$MASTER_SECRET" ]; then
    print_status 0 "Master credentials secret exists"
else
    print_status 1 "Master credentials secret not found"
fi

# 9. Verify CloudWatch Logs
print_info "Verifying CloudWatch logs..."
LOG_EXPORTS=$(aws rds describe-db-instances \
    --db-instance-identifier "$RDS_INSTANCE" \
    --region "$REGION" \
    --query 'DBInstances[0].EnabledCloudwatchLogsExports' \
    --output json 2>/dev/null)

if echo "$LOG_EXPORTS" | grep -q "postgresql"; then
    print_status 0 "CloudWatch logs are enabled"
else
    print_status 1 "CloudWatch logs are not enabled"
fi

# 10. Verify Performance Insights
print_info "Verifying Performance Insights..."
PERF_INSIGHTS=$(aws rds describe-db-instances \
    --db-instance-identifier "$RDS_INSTANCE" \
    --region "$REGION" \
    --query 'DBInstances[0].PerformanceInsightsEnabled' \
    --output text 2>/dev/null)

if [ "$PERF_INSIGHTS" == "True" ]; then
    print_status 0 "Performance Insights is enabled"
else
    echo -e "${YELLOW}[WARN] Performance Insights is disabled${NC}"
fi

# Summary
echo ""
echo "=========================================="
echo "Verification Summary"
echo "=========================================="
echo -e "${GREEN}Passed: $PASSED${NC}"
if [ $FAILED -gt 0 ]; then
    echo -e "${RED}Failed: $FAILED${NC}"
fi
echo "=========================================="

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All verification checks passed!${NC}"
    exit 0
else
    echo -e "${RED}Some verification checks failed. Please review.${NC}"
    exit 1
fi
