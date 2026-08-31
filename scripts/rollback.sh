#!/bin/bash

# Rollback Script for RDS Infrastructure
# Safely rolls back to a previous Terraform state version

set -e

STATE_VERSION="${1:-}"
ENVIRONMENT="${2:-dev}"
REGION="${3:-us-east-1}"

if [ -z "$STATE_VERSION" ]; then
    echo "Error: State version not provided"
    echo "Usage: $0 <state-version> [environment] [region]"
    echo ""
    echo "To list available versions:"
    echo "  aws s3api list-object-versions --bucket terraform-state-rds-platform-dev --prefix rds-platform/dev/terraform.tfstate"
    exit 1
fi

BUCKET="terraform-state-rds-platform-${ENVIRONMENT}"
KEY="rds-platform/${ENVIRONMENT}/terraform.tfstate"

echo "=========================================="
echo "RDS Infrastructure Rollback"
echo "=========================================="
echo "Environment: $ENVIRONMENT"
echo "Region: $REGION"
echo "State Bucket: $BUCKET"
echo "State Key: $KEY"
echo "Target Version: $STATE_VERSION"
echo "=========================================="
echo ""

# Warning
echo "WARNING: This will rollback your infrastructure to a previous state!"
echo "This action should only be performed in emergency situations."
echo ""
read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Rollback cancelled."
    exit 0
fi

# Backup current state
echo ""
echo "[1/5] Backing up current state..."
BACKUP_FILE="terraform.tfstate.backup-$(date +%Y%m%d-%H%M%S)"

aws s3 cp "s3://${BUCKET}/${KEY}" "$BACKUP_FILE" --region "$REGION"

if [ $? -eq 0 ]; then
    echo "✓ Current state backed up to: $BACKUP_FILE"
else
    echo "✗ Failed to backup current state"
    exit 1
fi

# Verify target version exists
echo ""
echo "[2/5] Verifying target version..."
VERSION_EXISTS=$(aws s3api list-object-versions \
    --bucket "$BUCKET" \
    --prefix "$KEY" \
    --region "$REGION" \
    --query "Versions[?VersionId=='${STATE_VERSION}'].VersionId" \
    --output text)

if [ -z "$VERSION_EXISTS" ]; then
    echo "✗ Version $STATE_VERSION not found"
    echo "Available versions:"
    aws s3api list-object-versions \
        --bucket "$BUCKET" \
        --prefix "$KEY" \
        --region "$REGION" \
        --query 'Versions[*].[VersionId,LastModified]' \
        --output table
    exit 1
fi

echo "✓ Target version verified"

# Download target state version
echo ""
echo "[3/5] Downloading target state version..."
TARGET_STATE="terraform.tfstate.rollback-${STATE_VERSION}"

aws s3api get-object \
    --bucket "$BUCKET" \
    --key "$KEY" \
    --version-id "$STATE_VERSION" \
    --region "$REGION" \
    "$TARGET_STATE"

if [ $? -eq 0 ]; then
    echo "✓ Target state downloaded: $TARGET_STATE"
else
    echo "✗ Failed to download target state"
    exit 1
fi

# Validate state file
echo ""
echo "[4/5] Validating state file..."
if cat "$TARGET_STATE" | jq . > /dev/null 2>&1; then
    echo "✓ State file is valid JSON"
else
    echo "✗ State file is corrupted or invalid"
    exit 1
fi

# Restore state
echo ""
echo "[5/5] Restoring state..."

aws s3 cp "$TARGET_STATE" "s3://${BUCKET}/${KEY}" --region "$REGION"

if [ $? -eq 0 ]; then
    echo "✓ State restored successfully"
else
    echo "✗ Failed to restore state"
    echo "Attempting to restore from backup..."
    aws s3 cp "$BACKUP_FILE" "s3://${BUCKET}/${KEY}" --region "$REGION"
    exit 1
fi

# Verify restoration
echo ""
echo "Verifying restoration..."
CURRENT_VERSION=$(aws s3api head-object \
    --bucket "$BUCKET" \
    --key "$KEY" \
    --region "$REGION" \
    --query 'VersionId' \
    --output text)

echo "Current state version: $CURRENT_VERSION"

echo ""
echo "=========================================="
echo "Rollback Summary"
echo "=========================================="
echo "Status: SUCCESS"
echo "Rolled back to version: $STATE_VERSION"
echo "Backup saved to: $BACKUP_FILE"
echo "=========================================="
echo ""
echo "IMPORTANT NEXT STEPS:"
echo "1. Navigate to terraform directory:"
echo "   cd terraform/environments/${ENVIRONMENT}"
echo ""
echo "2. Re-initialize Terraform:"
echo "   terraform init -reconfigure"
echo ""
echo "3. Verify the state:"
echo "   terraform plan"
echo ""
echo "4. If resources are out of sync, run:"
echo "   terraform apply"
echo ""
echo "5. To restore to current state, use:"
echo "   $0 <version-id-from-backup>"
echo "=========================================="

# Cleanup
rm -f "$TARGET_STATE"

echo ""
echo "Rollback completed successfully!"
