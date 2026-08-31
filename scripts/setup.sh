#!/bin/bash

# Complete Setup Script for RDS Platform Infrastructure
# This script automates the entire deployment process

set -e

ENVIRONMENT="${1:-dev}"
REGION="${2:-us-east-1}"

echo "=========================================="
echo "RDS Platform Infrastructure Setup"
echo "Environment: $ENVIRONMENT"
echo "Region: $REGION"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_step() {
    echo -e "${GREEN}[STEP $1]${NC} $2"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
print_step 1 "Checking prerequisites..."

if ! command -v terraform &> /dev/null; then
    print_error "Terraform is not installed"
    exit 1
fi

if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed"
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    print_warning "kubectl is not installed (required for Kubernetes setup)"
fi

echo "✓ All prerequisites met"
echo ""

# Verify AWS credentials
print_step 2 "Verifying AWS credentials..."
if aws sts get-caller-identity > /dev/null 2>&1; then
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    echo "✓ AWS credentials verified (Account: $ACCOUNT_ID)"
else
    print_error "AWS credentials not configured"
    exit 1
fi
echo ""

# Setup backend
print_step 3 "Setting up Terraform backend..."
BUCKET_NAME="terraform-state-rds-platform-${ENVIRONMENT}"

if aws s3 ls "s3://${BUCKET_NAME}" 2>&1 | grep -q 'NoSuchBucket'; then
    echo "Creating S3 bucket: $BUCKET_NAME"
    aws s3api create-bucket \
        --bucket "$BUCKET_NAME" \
        --region "$REGION"
    
    # Enable versioning
    aws s3api put-bucket-versioning \
        --bucket "$BUCKET_NAME" \
        --versioning-configuration Status=Enabled
    
    # Enable encryption
    aws s3api put-bucket-encryption \
        --bucket "$BUCKET_NAME" \
        --server-side-encryption-configuration '{
            "Rules": [{
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                }
            }]
        }'
    
    # Block public access
    aws s3api put-public-access-block \
        --bucket "$BUCKET_NAME" \
        --public-access-block-configuration \
            "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
    
    echo "✓ S3 bucket created and configured"
else
    echo "✓ S3 bucket already exists"
fi

# Create DynamoDB table
if aws dynamodb describe-table --table-name terraform-state-lock-rds-platform --region "$REGION" > /dev/null 2>&1; then
    echo "✓ DynamoDB table already exists"
else
    echo "Creating DynamoDB table for state locking"
    aws dynamodb create-table \
        --table-name terraform-state-lock-rds-platform \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
        --region "$REGION"
    echo "✓ DynamoDB table created"
fi
echo ""

# Check if terraform.tfvars exists
print_step 4 "Checking Terraform configuration..."
cd "terraform/environments/${ENVIRONMENT}"

if [ ! -f "terraform.tfvars" ]; then
    print_error "terraform.tfvars not found"
    echo "Please create terraform.tfvars from terraform.tfvars.example"
    echo "  cp terraform.tfvars.example terraform.tfvars"
    echo "  # Edit terraform.tfvars with your values"
    exit 1
fi
echo "✓ terraform.tfvars found"
echo ""

# Initialize Terraform
print_step 5 "Initializing Terraform..."
terraform init \
    -backend-config="bucket=${BUCKET_NAME}" \
    -backend-config="key=rds-platform/${ENVIRONMENT}/terraform.tfstate" \
    -backend-config="region=${REGION}" \
    -backend-config="encrypt=true" \
    -backend-config="dynamodb_table=terraform-state-lock-rds-platform" \
    -upgrade
echo "✓ Terraform initialized"
echo ""

# Validate Terraform
print_step 6 "Validating Terraform configuration..."
terraform validate
echo "✓ Terraform configuration is valid"
echo ""

# Create plan
print_step 7 "Creating Terraform plan..."
terraform plan -out=tfplan
echo "✓ Plan created"
echo ""

# Ask for confirmation
echo "=========================================="
echo "Ready to deploy infrastructure"
echo "=========================================="
read -p "Do you want to proceed with deployment? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Deployment cancelled"
    exit 0
fi

# Apply Terraform
print_step 8 "Applying Terraform changes..."
terraform apply tfplan
echo "✓ Infrastructure deployed"
echo ""

# Save outputs
print_step 9 "Saving Terraform outputs..."
terraform output -json > outputs.json
terraform output > outputs.txt
RDS_ENDPOINT=$(terraform output -raw rds_address)
echo "✓ Outputs saved"
echo "  RDS Endpoint: $RDS_ENDPOINT"
echo ""

# Run verification
print_step 10 "Verifying deployment..."
cd ../../../
./scripts/verify-deployment.sh "$ENVIRONMENT" "$REGION"
echo ""

# Initialize databases
print_step 11 "Initializing databases..."
echo "This will create all microservice databases and users"
read -p "Do you want to initialize databases now? (yes/no): " INIT_DB

if [ "$INIT_DB" == "yes" ]; then
    cd sql
    chmod +x execute-init.sh
    ./execute-init.sh "$RDS_ENDPOINT"
    cd ..
    echo "✓ Databases initialized"
else
    echo "Skipping database initialization"
    echo "You can run it later with: cd sql && ./execute-init.sh $RDS_ENDPOINT"
fi
echo ""

# Kubernetes setup
if command -v kubectl &> /dev/null; then
    print_step 12 "Setting up Kubernetes resources..."
    read -p "Do you want to deploy Kubernetes resources? (yes/no): " DEPLOY_K8S
    
    if [ "$DEPLOY_K8S" == "yes" ]; then
        # Update ConfigMaps with RDS endpoint
        find kubernetes/configmaps -name "*.yaml" -exec sed -i "s/<RDS_ENDPOINT>/${RDS_ENDPOINT}/g" {} \;
        
        # Create namespaces
        kubectl create namespace customer-service-ns --dry-run=client -o yaml | kubectl apply -f -
        kubectl create namespace order-service-ns --dry-run=client -o yaml | kubectl apply -f -
        kubectl create namespace catalog-service-ns --dry-run=client -o yaml | kubectl apply -f -
        kubectl create namespace order-history-service-ns --dry-run=client -o yaml | kubectl apply -f -
        kubectl create namespace notification-service-ns --dry-run=client -o yaml | kubectl apply -f -
        
        # Deploy SecretStores
        kubectl apply -f kubernetes/external-secrets/secret-store.yaml
        
        # Deploy ExternalSecrets
        kubectl apply -f kubernetes/external-secrets/
        
        # Deploy ConfigMaps
        kubectl apply -f kubernetes/configmaps/configmap-customer.yaml
        kubectl apply -f kubernetes/configmaps/configmap-order.yaml
        kubectl apply -f kubernetes/configmaps/configmap-catalog.yaml
        kubectl apply -f kubernetes/configmaps/configmap-order-history.yaml
        kubectl apply -f kubernetes/configmaps/configmap-notification.yaml
        
        echo "✓ Kubernetes resources deployed"
    fi
fi
echo ""

# Final summary
echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
echo ""
echo "Resources Created:"
echo "  ✓ RDS PostgreSQL Instance"
echo "  ✓ Database Subnet Group"
echo "  ✓ Security Groups"
echo "  ✓ AWS Secrets Manager (6 secrets)"
echo "  ✓ CloudWatch Logs & Alarms"
echo "  ✓ Kubernetes ConfigMaps & Secrets"
echo ""
echo "RDS Endpoint: $RDS_ENDPOINT"
echo ""
echo "Next Steps:"
echo "  1. Review CloudWatch alarms"
echo "  2. Test connectivity: ./scripts/test-connectivity.sh $RDS_ENDPOINT"
echo "  3. Deploy your microservices"
echo "  4. Monitor in CloudWatch"
echo ""
echo "Documentation:"
echo "  - Deployment Guide: docs/deployment-guide.md"
echo "  - Rollback Strategy: docs/rollback-strategy.md"
echo "  - Cost Estimation: docs/cost-estimation.md"
echo "=========================================="
