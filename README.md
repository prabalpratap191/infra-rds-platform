# Infrastructure RDS Platform

## Overview

Production-ready AWS RDS PostgreSQL infrastructure for Java microservices running on AWS EKS.

### Architecture

- **Region**: us-east-1
- **Database Engine**: Amazon RDS PostgreSQL 15.x
- **Infrastructure Tool**: Terraform v1.5+
- **Deployment Tool**: Jenkins
- **Secrets Storage**: AWS Secrets Manager
- **Environment**: Dev (extendable to Staging, Production)

### Microservices & Databases

| Microservice | Database | User | Namespace |
|--------------|----------|------|----------|
| customer-service | customer_db | customer_user | customer-service-ns |
| order-service | order_db | order_user | order-service-ns |
| catalog-service | catalog_db | catalog_user | catalog-service-ns |
| order-history-service | order_history_db | order_history_user | order-history-service-ns |
| notification-service | notification_db | notification_user | notification-service-ns |

## Features

✅ Multi-database support for microservices
✅ AWS Secrets Manager integration
✅ Automated backups & point-in-time recovery
✅ Multi-AZ support (configurable)
✅ Encryption at rest (AES-256)
✅ Storage autoscaling
✅ CloudWatch monitoring & alarms
✅ Private subnet deployment
✅ Security group isolation
✅ Kubernetes External Secrets integration
✅ Jenkins CI/CD pipeline

## Prerequisites

- AWS Account with appropriate permissions
- Terraform >= 1.5.0
- AWS CLI configured
- kubectl configured for EKS cluster
- Jenkins server with AWS credentials
- Existing VPC with private subnets
- EKS cluster security group ID

## Quick Start

### 1. Clone Repository

```bash
git clone <repository-url>
cd infra-rds-platform
```

### 2. Configure Variables

```bash
cd terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Plan & Apply

```bash
terraform plan -out=plan.out
terraform apply plan.out
```

## Repository Structure

```
infra-rds-platform/
├── terraform/
│   ├── modules/
│   │   ├── networking/          # Subnet groups
│   │   ├── rds/                 # RDS instance & databases
│   │   ├── secrets-manager/     # Secrets management
│   │   ├── monitoring/          # CloudWatch alarms
│   │   └── security-group/      # Security groups
│   ├── environments/
│   │   └── dev/                 # Dev environment configs
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── backend.tf
│   └── providers.tf
├── sql/
│   └── init-databases.sql       # Database initialization
├── kubernetes/
│   ├── external-secrets/        # External Secrets configs
│   ├── secrets/                 # Kubernetes secrets templates
│   └── configmaps/              # ConfigMaps for each service
├── jenkins/
│   └── Jenkinsfile              # CI/CD pipeline
├── scripts/
│   ├── verify-deployment.sh     # Deployment verification
│   ├── test-connectivity.sh     # Network connectivity tests
│   └── rollback.sh              # Rollback automation
├── docs/
│   ├── deployment-guide.md
│   ├── rollback-strategy.md
│   └── cost-estimation.md
└── README.md
```

## Deployment

### Manual Deployment

```bash
cd terraform/environments/dev
terraform init
terraform plan
terraform apply
```

### Jenkins Deployment

**See [docs/JENKINS_SETUP.md](docs/JENKINS_SETUP.md) for complete Jenkins configuration guide.**

1. Install required Jenkins plugins (Pipeline, AWS Steps, Git)
2. Configure AWS credentials in Jenkins (ID: `aws-credentials`)
3. Create Jenkins pipeline job pointing to `jenkins/Jenkinsfile`
4. Run pipeline with parameters:
   - ACTION: plan/apply/destroy
   - ENVIRONMENT: dev/staging/prod
   - AUTO_APPROVE: false (recommended)

## Database Access

### From EC2 Bastion

```bash
ssh -i <key.pem> ec2-user@<bastion-ip>
psql -h <rds-endpoint> -U customer_user -d customer_db
```

### From Kubernetes Pods

Credentials are automatically injected via External Secrets Operator.

```yaml
spring:
  datasource:
    url: jdbc:postgresql://${DB_HOST}:5432/${DB_NAME}
    username: ${DB_USERNAME}
    password: ${DB_PASSWORD}
```

## Monitoring

- **CloudWatch Alarms**: CPU, Memory, Storage, Connections
- **Performance Insights**: Enabled for query analysis
- **Enhanced Monitoring**: 60-second granularity

## Security

- ✅ Private subnet deployment
- ✅ No public access
- ✅ Encryption at rest (KMS)
- ✅ Encryption in transit (SSL)
- ✅ Secrets in AWS Secrets Manager
- ✅ IAM database authentication (optional)
- ✅ Security group ingress from EKS only

## Backup & Recovery

- **Automated Backups**: Daily, 7-day retention
- **Manual Snapshots**: On-demand
- **Point-in-Time Recovery**: Up to 7 days
- **Cross-Region Replication**: Optional

## Cost Estimation

See [docs/cost-estimation.md](docs/cost-estimation.md) for detailed breakdown.

**Estimated Monthly Cost (Dev)**:
- RDS db.t3.medium: ~$60
- Storage (100GB): ~$12
- Backups: ~$5
- Secrets Manager: ~$2
- **Total**: ~$79/month

## Troubleshooting

### Connection Issues

```bash
# Test from bastion
telnet <rds-endpoint> 5432

# Verify security groups
aws ec2 describe-security-groups --group-ids <sg-id>
```

### Check Secrets

```bash
aws secretsmanager get-secret-value --secret-id rds/dev/customer-service
```

## Rollback

See [docs/rollback-strategy.md](docs/rollback-strategy.md)

```bash
# Quick rollback
./scripts/rollback.sh <previous-state-version>
```

## Contributing

1. Create feature branch
2. Make changes
3. Run `terraform fmt` and `terraform validate`
4. Submit pull request

## Support

For issues and questions, please open a GitHub issue.

## License

MIT License
"# infra-rds-platform" 
