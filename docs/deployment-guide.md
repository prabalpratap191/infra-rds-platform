# RDS Platform Deployment Guide

## Overview

This guide provides step-by-step instructions for deploying the RDS PostgreSQL infrastructure for microservices.

## Prerequisites

### Required Tools

- **Terraform** >= 1.5.0
- **AWS CLI** >= 2.0
- **kubectl** >= 1.24 (for Kubernetes integration)
- **jq** (for JSON processing)
- **psql** (PostgreSQL client)

### AWS Resources

Before deployment, ensure you have:

1. **VPC** with at least 2 private subnets in different AZs
2. **EKS cluster** with worker nodes
3. **Security group** ID for EKS worker nodes
4. **Bastion host** (optional) for database access
5. **IAM permissions** for:
   - RDS creation and management
   - Secrets Manager
   - CloudWatch
   - VPC and Security Groups

### AWS Credentials

Configure AWS credentials:

```bash
aws configure
# or
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"
```

## Deployment Steps

### Step 1: Clone Repository

```bash
git clone <repository-url>
cd infra-rds-platform
```

### Step 2: Configure Backend

Create S3 bucket and DynamoDB table for Terraform state:

```bash
# Create S3 bucket
aws s3api create-bucket \
    --bucket terraform-state-rds-platform-dev \
    --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
    --bucket terraform-state-rds-platform-dev \
    --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
    --bucket terraform-state-rds-platform-dev \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            }
        }]
    }'

# Block public access
aws s3api put-public-access-block \
    --bucket terraform-state-rds-platform-dev \
    --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Create DynamoDB table for state locking
aws dynamodb create-table \
    --table-name terraform-state-lock-rds-platform \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
    --region us-east-1
```

### Step 3: Configure Variables

Navigate to the dev environment:

```bash
cd terraform/environments/dev
```

Create `terraform.tfvars` from example:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your values:

```hcl
# REQUIRED: Update these values
vpc_id = "vpc-0123456789abcdef0"
private_subnet_ids = [
  "subnet-0123456789abcdef0",
  "subnet-0123456789abcdef1",
]
eks_security_group_id = "sg-0123456789abcdef0"
bastion_security_group_id = "sg-0123456789abcdef1"  # Optional

# Optional: Customize instance settings
db_instance_class = "db.t3.medium"
db_allocated_storage = 100
multi_az = false  # true for production
```

### Step 4: Initialize Terraform

```bash
terraform init
```

Expected output:
```
Terraform has been successfully initialized!
```

### Step 5: Validate Configuration

```bash
terraform validate
```

### Step 6: Plan Deployment

```bash
terraform plan -out=tfplan
```

Review the plan carefully. Look for:
- ✅ Resources to be created
- ⚠️ Resources to be modified
- ❌ Resources to be destroyed (should be none for initial deployment)

### Step 7: Apply Configuration

```bash
terraform apply tfplan
```

This will create:
- RDS PostgreSQL instance
- DB subnet group
- Security groups
- Secrets in AWS Secrets Manager
- CloudWatch log groups and alarms
- IAM roles for monitoring

Deployment time: ~15-20 minutes

### Step 8: Retrieve Outputs

After successful deployment:

```bash
terraform output
```

Important outputs:
- `rds_endpoint` - Database connection endpoint
- `secrets_manager_arns` - ARNs for each microservice secret
- `rds_security_group_id` - Security group ID

### Step 9: Verify Deployment

Run verification script:

```bash
cd ../../..
./scripts/verify-deployment.sh dev
```

This checks:
- ✅ RDS instance status
- ✅ Encryption settings
- ✅ Security groups
- ✅ Secrets Manager
- ✅ CloudWatch configuration

### Step 10: Initialize Databases

Execute SQL initialization script:

```bash
cd sql
chmod +x execute-init.sh

# Get RDS endpoint from Terraform output
RDS_ENDPOINT=$(cd ../terraform/environments/dev && terraform output -raw rds_address)

./execute-init.sh $RDS_ENDPOINT
```

This creates:
- 5 databases (customer_db, order_db, catalog_db, order_history_db, notification_db)
- 5 users with permissions
- Proper schema privileges

### Step 11: Test Connectivity

Test database connectivity:

```bash
cd ../scripts
chmod +x test-connectivity.sh
./test-connectivity.sh $RDS_ENDPOINT
```

### Step 12: Deploy Kubernetes Resources

#### Install External Secrets Operator

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

helm install external-secrets \
    external-secrets/external-secrets \
    -n external-secrets-system \
    --create-namespace
```

#### Create Namespaces

```bash
kubectl create namespace customer-service-ns
kubectl create namespace order-service-ns
kubectl create namespace catalog-service-ns
kubectl create namespace order-history-service-ns
kubectl create namespace notification-service-ns
```

#### Create IAM Role for External Secrets

```bash
# Create OIDC provider for your EKS cluster (if not already done)
eksctl utils associate-iam-oidc-provider --cluster=<your-cluster-name> --approve

# Create IAM policy and role (see Kubernetes integration docs)
```

#### Deploy SecretStores

```bash
kubectl apply -f kubernetes/external-secrets/secret-store.yaml
```

#### Deploy ExternalSecrets

```bash
kubectl apply -f kubernetes/external-secrets/external-secret-customer.yaml
kubectl apply -f kubernetes/external-secrets/external-secret-order.yaml
kubectl apply -f kubernetes/external-secrets/external-secret-catalog.yaml
kubectl apply -f kubernetes/external-secrets/external-secret-order-history.yaml
kubectl apply -f kubernetes/external-secrets/external-secret-notification.yaml
```

#### Update and Deploy ConfigMaps

Update RDS endpoint in ConfigMaps:

```bash
# Replace <RDS_ENDPOINT> with actual value
RDS_ENDPOINT=$(cd terraform/environments/dev && terraform output -raw rds_address)

find kubernetes/configmaps -name "*.yaml" -exec sed -i "s/<RDS_ENDPOINT>/${RDS_ENDPOINT}/g" {} \;

# Deploy ConfigMaps
kubectl apply -f kubernetes/configmaps/configmap-customer.yaml
kubectl apply -f kubernetes/configmaps/configmap-order.yaml
kubectl apply -f kubernetes/configmaps/configmap-catalog.yaml
kubectl apply -f kubernetes/configmaps/configmap-order-history.yaml
kubectl apply -f kubernetes/configmaps/configmap-notification.yaml
```

#### Verify Kubernetes Resources

```bash
# Verify ExternalSecrets
kubectl get externalsecrets -A

# Verify synced secrets
kubectl get secrets -n customer-service-ns
kubectl get secrets -n order-service-ns
# ... etc

# Verify ConfigMaps
kubectl get configmaps -A | grep db-config
```

## Post-Deployment

### Access Database from Bastion

```bash
ssh -i <key.pem> ec2-user@<bastion-ip>

# Install PostgreSQL client
sudo yum install -y postgresql15

# Connect to database
psql -h <rds-endpoint> -U customer_user -d customer_db
```

### Access from Application

In your Spring Boot application:

```yaml
spring:
  datasource:
    url: jdbc:postgresql://${DB_HOST}:${DB_PORT}/${DB_NAME}?sslmode=require
    username: ${DB_USERNAME}
    password: ${DB_PASSWORD}
```

Environment variables are injected automatically via External Secrets.

## Troubleshooting

### Connection Timeout

**Problem**: Cannot connect to RDS from EKS

**Solutions**:
1. Check security group rules
2. Verify subnet routing
3. Ensure RDS is in private subnet
4. Check Network ACLs

### Authentication Failed

**Problem**: Password authentication failed

**Solutions**:
1. Verify credentials in Secrets Manager
2. Check user exists in database
3. Verify database name is correct

### Terraform State Lock

**Problem**: State locked by another operation

**Solution**:
```bash
terraform force-unlock <lock-id>
```

## Rollback

See [rollback-strategy.md](rollback-strategy.md) for detailed rollback procedures.

## Support

For issues:
1. Check CloudWatch logs
2. Run verification script
3. Review Terraform state
4. Open GitHub issue

## Next Steps

1. Enable automated backups monitoring
2. Set up SNS notifications for alarms
3. Configure cross-region replication (if needed)
4. Implement database migration strategy
5. Set up monitoring dashboards
