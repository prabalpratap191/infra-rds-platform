# Quick Start Guide

## 5-Minute Setup

### Prerequisites Checklist

- [ ] AWS Account with appropriate permissions
- [ ] AWS CLI configured (`aws configure`)
- [ ] Terraform >= 1.5.0 installed
- [ ] Existing VPC with 2+ private subnets
- [ ] EKS cluster with worker nodes
- [ ] EKS security group ID

### Step 1: Clone Repository

```bash
git clone <repository-url>
cd infra-rds-platform
```

### Step 2: Configure Backend

```bash
# Create S3 bucket for Terraform state
aws s3api create-bucket --bucket terraform-state-rds-platform-dev --region us-east-1
aws s3api put-bucket-versioning --bucket terraform-state-rds-platform-dev --versioning-configuration Status=Enabled

# Create DynamoDB table for state locking
aws dynamodb create-table \
    --table-name terraform-state-lock-rds-platform \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
    --region us-east-1
```

### Step 3: Configure Variables

```bash
cd terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars - REQUIRED VALUES:
# - vpc_id
# - private_subnet_ids (at least 2)
# - eks_security_group_id
vim terraform.tfvars
```

### Step 4: Deploy Infrastructure

**Option A: Automated (Recommended)**
```bash
cd ../../..
chmod +x scripts/setup.sh
./scripts/setup.sh dev
```

**Option B: Manual**
```bash
cd terraform/environments/dev
terraform init
terraform plan
terraform apply
```

### Step 5: Initialize Databases

```bash
# Get RDS endpoint from Terraform output
RDS_ENDPOINT=$(cd terraform/environments/dev && terraform output -raw rds_address)

# Run initialization script
cd sql
chmod +x execute-init.sh
./execute-init.sh $RDS_ENDPOINT
```

### Step 6: Deploy Kubernetes Resources

```bash
# Create namespaces
for ns in customer-service-ns order-service-ns catalog-service-ns \
          order-history-service-ns notification-service-ns; do
    kubectl create namespace $ns
done

# Deploy External Secrets
kubectl apply -f kubernetes/external-secrets/

# Update ConfigMaps with RDS endpoint
find kubernetes/configmaps -name "*.yaml" -exec sed -i "s/<RDS_ENDPOINT>/${RDS_ENDPOINT}/g" {} \;

# Deploy ConfigMaps
kubectl apply -f kubernetes/configmaps/
```

## Verify Deployment

```bash
./scripts/verify-deployment.sh dev
```

## Test Connectivity

```bash
./scripts/test-connectivity.sh $RDS_ENDPOINT
```

## Access Database

### From Bastion Host

```bash
ssh -i <key.pem> ec2-user@<bastion-ip>
psql -h $RDS_ENDPOINT -U customer_user -d customer_db
```

### From Application

Environment variables are automatically injected:

```yaml
env:
- name: DB_HOST
  valueFrom:
    configMapKeyRef:
      name: customer-db-config
      key: DB_HOST
- name: DB_USERNAME
  valueFrom:
    secretKeyRef:
      name: customer-db-credentials
      key: username
```

## Common Commands

### Terraform

```bash
# Plan changes
terraform plan

# Apply changes
terraform apply

# Show outputs
terraform output

# Destroy infrastructure
terraform destroy
```

### AWS CLI

```bash
# Check RDS status
aws rds describe-db-instances --db-instance-identifier rds-platform-dev-postgres

# Get secret value
aws secretsmanager get-secret-value --secret-id rds/dev/customer-service

# List snapshots
aws rds describe-db-snapshots --db-instance-identifier rds-platform-dev-postgres
```

### Kubernetes

```bash
# Check ExternalSecrets
kubectl get externalsecrets -A

# Check synced secrets
kubectl get secrets -n customer-service-ns

# Check ConfigMaps
kubectl get configmaps -A | grep db-config

# Describe ExternalSecret
kubectl describe externalsecret customer-db-credentials -n customer-service-ns
```

## Troubleshooting

### Can't connect to RDS

```bash
# Check security groups
aws ec2 describe-security-groups --group-ids <sg-id>

# Test connectivity
./scripts/test-connectivity.sh $RDS_ENDPOINT

# Check from within pod
kubectl run -it --rm debug --image=postgres:15 --restart=Never -- bash
psql -h $RDS_ENDPOINT -U customer_user -d customer_db
```

### Secrets not syncing

```bash
# Check External Secrets Operator
kubectl get pods -n external-secrets-system

# Check logs
kubectl logs -n external-secrets-system deployment/external-secrets

# Verify SecretStore
kubectl get secretstore -A

# Force refresh
kubectl annotate externalsecret customer-db-credentials -n customer-service-ns \
    force-sync="$(date +%s)"
```

### Terraform state locked

```bash
# Force unlock
terraform force-unlock <lock-id>
```

## Rollback

```bash
# List state versions
aws s3api list-object-versions \
    --bucket terraform-state-rds-platform-dev \
    --prefix rds-platform/dev/terraform.tfstate

# Rollback to previous version
./scripts/rollback.sh <version-id> dev
```

## Monitoring

### CloudWatch Console

1. Go to CloudWatch Console
2. Navigate to Alarms
3. Filter by "rds-platform-dev"

### View Logs

```bash
# Stream logs
aws logs tail /aws/rds/instance/rds-platform-dev-postgres --follow

# Query logs
aws logs filter-log-events \
    --log-group-name /aws/rds/instance/rds-platform-dev-postgres \
    --filter-pattern "ERROR"
```

## Cost Tracking

```bash
# Get current month cost
aws ce get-cost-and-usage \
    --time-period Start=2024-01-01,End=2024-01-31 \
    --granularity MONTHLY \
    --metrics BlendedCost \
    --filter file://filter.json
```

## Jenkins Pipeline

1. Create Jenkins pipeline job
2. Point to `jenkins/Jenkinsfile`
3. Configure parameters:
   - ACTION: plan/apply/destroy
   - ENVIRONMENT: dev/staging/prod
   - AUTO_APPROVE: false
4. Run pipeline

## Next Steps

1. ✅ Review [Deployment Guide](docs/deployment-guide.md)
2. ✅ Set up CloudWatch alarms SNS notifications
3. ✅ Configure automated backups monitoring
4. ✅ Review [Cost Estimation](docs/cost-estimation.md)
5. ✅ Implement [Rollback Strategy](docs/rollback-strategy.md)
6. ✅ Deploy your microservices

## Support

- Documentation: `/docs`
- Architecture: [docs/architecture.md](docs/architecture.md)
- Issues: GitHub Issues
- Email: devops@company.com

## Useful Links

- [AWS RDS Documentation](https://docs.aws.amazon.com/rds/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/15/)
- [External Secrets Operator](https://external-secrets.io/)
