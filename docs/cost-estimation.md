# AWS RDS Platform Cost Estimation

## Overview

This document provides detailed cost estimation for the RDS PostgreSQL infrastructure across different environments.

## Monthly Cost Breakdown - Development Environment

### RDS Instance Costs

| Component | Specification | Monthly Cost (USD) |
|-----------|--------------|-------------------|
| **Instance Type** | db.t3.medium (2 vCPU, 4GB RAM) | $62.56 |
| **Storage** | 100 GB gp3 | $11.50 |
| **Storage IOPS** | 3,000 IOPS (baseline) | Included |
| **Backup Storage** | 100 GB (same as allocated) | $0.00 (free tier) |
| **Additional Backup** | 50 GB extra | $4.75 |
| **Snapshot Export** | Occasional (10 GB/month) | $1.00 |

**Subtotal RDS**: ~$79.81/month

### Secrets Manager Costs

| Component | Specification | Monthly Cost (USD) |
|-----------|--------------|-------------------|
| **Secrets** | 6 secrets (1 master + 5 services) | $2.40 |
| **API Calls** | ~100,000 calls/month | $0.05 |

**Subtotal Secrets Manager**: ~$2.45/month

### CloudWatch Costs

| Component | Specification | Monthly Cost (USD) |
|-----------|--------------|-------------------|
| **Metrics** | 7 custom metrics | $2.10 |
| **Alarms** | 7 alarms | $0.70 |
| **Log Ingestion** | 5 GB/month | $2.50 |
| **Log Storage** | 10 GB (30-day retention) | $0.50 |
| **Performance Insights** | 7-day retention | Free |

**Subtotal CloudWatch**: ~$5.80/month

### Data Transfer Costs

| Component | Specification | Monthly Cost (USD) |
|-----------|--------------|-------------------|
| **Within AZ** | Free | $0.00 |
| **Cross-AZ** | 10 GB/month | $1.00 |
| **Internet (backup DLs)** | 5 GB/month | $0.45 |

**Subtotal Data Transfer**: ~$1.45/month

### **Total Development Cost**: ~$89.51/month (~$1,074/year)

---

## Monthly Cost Breakdown - Production Environment

### RDS Instance Costs

| Component | Specification | Monthly Cost (USD) |
|-----------|--------------|-------------------|
| **Instance Type** | db.r5.xlarge (4 vCPU, 32GB RAM) | $435.60 |
| **Multi-AZ** | 100% additional | $435.60 |
| **Storage** | 500 GB gp3 | $57.50 |
| **Storage IOPS** | 12,000 provisioned | $60.00 |
| **Backup Storage** | 500 GB (free tier) | $0.00 |
| **Additional Backup** | 1,000 GB extra | $95.00 |
| **Cross-Region Backup** | 500 GB | $125.00 |

**Subtotal RDS**: ~$1,208.70/month

### Secrets Manager Costs

| Component | Specification | Monthly Cost (USD) |
|-----------|--------------|-------------------|
| **Secrets** | 6 secrets | $2.40 |
| **API Calls** | ~1,000,000 calls/month | $0.50 |

**Subtotal Secrets Manager**: ~$2.90/month

### CloudWatch Costs

| Component | Specification | Monthly Cost (USD) |
|-----------|--------------|-------------------|
| **Metrics** | 20 custom metrics | $6.00 |
| **Alarms** | 15 alarms | $1.50 |
| **Log Ingestion** | 50 GB/month | $25.00 |
| **Log Storage** | 200 GB (90-day retention) | $10.00 |
| **Performance Insights** | 731-day retention | $16.00 |

**Subtotal CloudWatch**: ~$58.50/month

### Data Transfer Costs

| Component | Specification | Monthly Cost (USD) |
|-----------|--------------|-------------------|
| **Within AZ** | Free | $0.00 |
| **Cross-AZ** | 200 GB/month | $20.00 |
| **Internet** | 50 GB/month | $4.50 |
| **Cross-Region Replication** | 100 GB/month | $20.00 |

**Subtotal Data Transfer**: ~$44.50/month

### **Total Production Cost**: ~$1,314.60/month (~$15,775/year)

---

## Cost Comparison by Environment

| Environment | RDS | Secrets | CloudWatch | Transfer | **Total/Month** | **Total/Year** |
|-------------|-----|---------|------------|----------|-----------------|----------------|
| **Development** | $79.81 | $2.45 | $5.80 | $1.45 | **$89.51** | **$1,074** |
| **Staging** | $159.62 | $2.45 | $15.00 | $5.00 | **$182.07** | **$2,185** |
| **Production** | $1,208.70 | $2.90 | $58.50 | $44.50 | **$1,314.60** | **$15,775** |

---

## Cost Optimization Strategies

### 1. Right-Sizing Instances

**Current**: db.t3.medium (Dev)
**Optimized**: db.t3.small
**Savings**: ~$30/month

```bash
# Modify instance class
aws rds modify-db-instance \
    --db-instance-identifier rds-platform-dev-postgres \
    --db-instance-class db.t3.small \
    --apply-immediately
```

### 2. Storage Optimization

**Strategy**: Use gp3 instead of gp2
**Savings**: ~20% on storage costs

**Current**: 100 GB gp2 = $11.50/month
**Optimized**: 100 GB gp3 = $9.20/month
**Savings**: $2.30/month

### 3. Backup Optimization

**Strategy**: Reduce backup retention for dev

```hcl
backup_retention_period = 3  # Instead of 7
```

**Savings**: ~$2/month

### 4. Log Retention Optimization

**Current**: 30-day retention
**Optimized**: 7-day retention (dev)
**Savings**: ~$1.50/month

```hcl
resource "aws_cloudwatch_log_group" "rds" {
  retention_in_days = 7  # Instead of 30
}
```

### 5. Reserved Instances

**1-Year Reserved Instance**:
- Upfront payment: $450
- Effective monthly: $37.50
- Savings: 40% vs On-Demand

**3-Year Reserved Instance**:
- Upfront payment: $900
- Effective monthly: $25.00
- Savings: 60% vs On-Demand

### 6. Stop Dev Environment After Hours

**Automated shutdown** (8 hours/day, 5 days/week):
- Running time: ~184 hours/month (vs 730)
- Savings: ~60% on compute costs
- Monthly savings: ~$37/month

```bash
# Stop instance
aws rds stop-db-instance --db-instance-identifier rds-platform-dev-postgres

# Start instance
aws rds start-db-instance --db-instance-identifier rds-platform-dev-postgres
```

### 7. Reduce Multi-AZ in Non-Prod

**Current**: Multi-AZ enabled
**Optimized**: Single-AZ for dev/staging
**Savings**: 50% on instance costs

---

## Cost Monitoring

### Set Up AWS Budgets

```bash
aws budgets create-budget \
    --account-id <account-id> \
    --budget file://budget.json \
    --notifications-with-subscribers file://notifications.json
```

**budget.json**:
```json
{
  "BudgetName": "RDS-Platform-Monthly",
  "BudgetLimit": {
    "Amount": "150",
    "Unit": "USD"
  },
  "TimeUnit": "MONTHLY",
  "BudgetType": "COST"
}
```

### Cost Allocation Tags

Ensure all resources have these tags:
```hcl
tags = {
  Environment = "dev"
  Project     = "rds-platform"
  CostCenter  = "engineering"
  Owner       = "devops-team"
}
```

### CloudWatch Cost Dashboard

Create custom dashboard:
```bash
aws cloudwatch put-dashboard \
    --dashboard-name RDS-Cost-Monitoring \
    --dashboard-body file://dashboard.json
```

---

## Total Cost of Ownership (TCO) - 3 Years

### Option 1: On-Demand (Current Setup)

| Environment | Year 1 | Year 2 | Year 3 | **Total** |
|-------------|--------|--------|--------|----------|
| Development | $1,074 | $1,074 | $1,074 | **$3,222** |
| Staging | $2,185 | $2,185 | $2,185 | **$6,555** |
| Production | $15,775 | $15,775 | $15,775 | **$47,325** |
| **Total** | $19,034 | $19,034 | $19,034 | **$57,102** |

### Option 2: Reserved Instances (3-Year)

| Environment | Upfront | Year 1-3 | **Total** |
|-------------|---------|----------|----------|
| Development | $450 | $1,350 | **$1,800** |
| Production | $5,400 | $16,200 | **$21,600** |
| **Total Savings** | | | **~$33,702** (59%) |

---

## Scaling Cost Projection

### Additional Microservices

For each new microservice:
- Secrets Manager: +$0.40/month
- Database creation: $0 (uses same RDS instance)
- CloudWatch logs: +$0.50/month

**Cost per additional service**: ~$0.90/month

### Scaling to 20 Microservices

Additional 15 services:
- Additional cost: 15 × $0.90 = $13.50/month
- Total: $89.51 + $13.50 = **$103.01/month**

---

## Cost Recommendations

### Development Environment

1. ✅ Use db.t3.small instead of db.t3.medium → Save $30/month
2. ✅ Reduce backup retention to 3 days → Save $2/month
3. ✅ Use 7-day log retention → Save $1.50/month
4. ✅ Stop instance after hours → Save $37/month

**Total Dev Savings**: ~$70.50/month (~79% reduction)
**Optimized Dev Cost**: ~$19/month

### Production Environment

1. ✅ Purchase 3-year reserved instance → Save $9,525/year
2. ✅ Optimize log retention (30 days) → Save $5/month
3. ✅ Enable storage autoscaling → Avoid over-provisioning
4. ✅ Use lifecycle policies for backups → Save $20/month

**Total Prod Savings**: ~$10,000/year

---

## Cost Tracking Tools

1. **AWS Cost Explorer** - Daily cost monitoring
2. **AWS Budgets** - Set alerts at 80%, 90%, 100%
3. **CloudWatch Dashboards** - Real-time metrics
4. **Terraform Cost Estimation** - Pre-deployment analysis
5. **Infracost** - Cost changes in PR reviews

---

## Conclusion

Estimated monthly costs:
- **Development**: $89.51 (optimizable to ~$19)
- **Production**: $1,314.60 (optimizable to ~$1,095 with RI)

Recommended actions:
1. Implement cost optimization strategies
2. Purchase reserved instances for production
3. Set up cost monitoring and alerts
4. Review and optimize quarterly

---

## Additional Resources

- [AWS RDS Pricing](https://aws.amazon.com/rds/pricing/)
- [AWS Secrets Manager Pricing](https://aws.amazon.com/secrets-manager/pricing/)
- [AWS CloudWatch Pricing](https://aws.amazon.com/cloudwatch/pricing/)
- [Cost Optimization Best Practices](https://aws.amazon.com/pricing/cost-optimization/)
