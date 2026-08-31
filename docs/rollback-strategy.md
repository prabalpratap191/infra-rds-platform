# Rollback Strategy

## Overview

This document outlines the rollback strategy for the RDS infrastructure in case of deployment failures or issues.

## Rollback Scenarios

### 1. Terraform Apply Failure

**Scenario**: `terraform apply` fails mid-execution

**Impact**: Partial infrastructure created, inconsistent state

**Recovery Steps**:

```bash
# 1. Review the error
terraform show

# 2. Attempt to fix the issue and re-apply
terraform apply

# 3. If unfixable, destroy partial resources
terraform destroy -target=<resource>
```

### 2. Database Configuration Error

**Scenario**: Database initialized with incorrect settings

**Impact**: Application connectivity issues

**Recovery Steps**:

```bash
# 1. Access RDS via bastion
psql -h <rds-endpoint> -U postgres

# 2. Fix user permissions
GRANT ALL PRIVILEGES ON DATABASE customer_db TO customer_user;

# 3. Or re-run initialization
cd sql
./execute-init.sh <rds-endpoint>
```

### 3. State File Corruption

**Scenario**: Terraform state file corrupted or lost

**Impact**: Cannot manage infrastructure

**Recovery Steps**:

```bash
# 1. List available state versions
aws s3api list-object-versions \
    --bucket terraform-state-rds-platform-dev \
    --prefix rds-platform/dev/terraform.tfstate

# 2. Use rollback script
./scripts/rollback.sh <version-id> dev

# 3. Verify state
cd terraform/environments/dev
terraform plan
```

### 4. Breaking Change Deployed

**Scenario**: New infrastructure changes break applications

**Impact**: Application downtime

**Recovery Steps**:

**Option A: Rollback Terraform State**

```bash
# 1. Find previous working version
aws s3api list-object-versions \
    --bucket terraform-state-rds-platform-dev \
    --prefix rds-platform/dev/terraform.tfstate \
    --query 'Versions[*].[VersionId,LastModified]' \
    --output table

# 2. Rollback to previous version
./scripts/rollback.sh <previous-version-id> dev

# 3. Re-initialize and verify
cd terraform/environments/dev
terraform init -reconfigure
terraform plan
```

**Option B: Revert Git Changes**

```bash
# 1. Find last working commit
git log --oneline

# 2. Revert to previous commit
git revert <commit-hash>

# 3. Re-deploy
terraform plan
terraform apply
```

### 5. RDS Instance Failure

**Scenario**: RDS instance becomes unavailable

**Impact**: Complete database outage

**Recovery Steps**:

**Option A: Restore from Automated Backup**

```bash
# 1. List available snapshots
aws rds describe-db-snapshots \
    --db-instance-identifier rds-platform-dev-postgres

# 2. Restore from snapshot
aws rds restore-db-instance-from-db-snapshot \
    --db-instance-identifier rds-platform-dev-postgres-restored \
    --db-snapshot-identifier <snapshot-id>

# 3. Update DNS/endpoint in applications
```

**Option B: Point-in-Time Recovery**

```bash
aws rds restore-db-instance-to-point-in-time \
    --source-db-instance-identifier rds-platform-dev-postgres \
    --target-db-instance-identifier rds-platform-dev-postgres-pitr \
    --restore-time 2024-01-15T10:00:00Z
```

### 6. Security Group Misconfiguration

**Scenario**: Security group rules prevent database access

**Impact**: Applications cannot connect

**Recovery Steps**:

```bash
# 1. Identify security group
SG_ID=$(terraform output -raw rds_security_group_id)

# 2. Add temporary rule
aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp \
    --port 5432 \
    --source-group <eks-sg-id>

# 3. Fix in Terraform and re-apply
terraform apply
```

### 7. Secrets Manager Issues

**Scenario**: Credentials lost or corrupted in Secrets Manager

**Impact**: Applications cannot authenticate

**Recovery Steps**:

```bash
# 1. Reset password in RDS
psql -h <rds-endpoint> -U postgres
ALTER USER customer_user WITH PASSWORD 'new-password';

# 2. Update secret
aws secretsmanager update-secret \
    --secret-id rds/dev/customer-service \
    --secret-string '{"username":"customer_user","password":"new-password","database":"customer_db","port":5432}'

# 3. Restart application pods
kubectl rollout restart deployment customer-service -n customer-service-ns
```

## Rollback Decision Matrix

| Scenario | Severity | Rollback Method | Downtime | Data Loss Risk |
|----------|----------|-----------------|----------|----------------|
| Terraform failure | Medium | Fix & re-apply | None | None |
| DB config error | Low | Re-run SQL | Minimal | None |
| State corruption | High | State rollback | None | None |
| Breaking change | High | Git revert + apply | Medium | None |
| RDS failure | Critical | Snapshot restore | High | Minimal |
| Security group | Medium | Manual fix | Medium | None |
| Secrets issue | Medium | Update secret | Low | None |

## Automated Rollback

### Jenkins Pipeline Rollback

```groovy
// Add to Jenkinsfile
stage('Rollback') {
    when {
        expression { params.ACTION == 'rollback' }
    }
    steps {
        script {
            sh './scripts/rollback.sh ${params.STATE_VERSION} ${params.ENVIRONMENT}'
        }
    }
}
```

## Pre-Rollback Checklist

- [ ] Identify exact issue and root cause
- [ ] Document current state
- [ ] Create snapshot/backup of current state
- [ ] Notify stakeholders of rollback
- [ ] Verify rollback target is stable
- [ ] Plan communication strategy
- [ ] Prepare monitoring for post-rollback

## Post-Rollback Checklist

- [ ] Verify RDS instance is healthy
- [ ] Test database connectivity
- [ ] Verify application connectivity
- [ ] Check CloudWatch metrics
- [ ] Validate Secrets Manager
- [ ] Update documentation
- [ ] Conduct post-mortem

## Emergency Contacts

| Role | Contact | Responsibility |
|------|---------|----------------|
| DevOps Lead | devops-lead@company.com | Infrastructure decisions |
| DBA | dba@company.com | Database recovery |
| Security | security@company.com | Secrets and access |
| On-Call Engineer | oncall@company.com | 24/7 support |

## Rollback Testing

Regularly test rollback procedures:

```bash
# Quarterly rollback drill
1. Deploy to test environment
2. Introduce breaking change
3. Execute rollback
4. Verify recovery
5. Document lessons learned
```

## Prevention Strategies

1. **Always run `terraform plan` before apply**
2. **Use approval gates in CI/CD**
3. **Enable Multi-AZ for production**
4. **Maintain backup retention**
5. **Test changes in dev first**
6. **Use feature flags for application changes**
7. **Monitor metrics during deployment**
8. **Implement blue/green deployments**

## State Version History

Maintain log of state versions:

```bash
# Create version log
aws s3api list-object-versions \
    --bucket terraform-state-rds-platform-dev \
    --prefix rds-platform/dev/terraform.tfstate \
    --query 'Versions[*].[VersionId,LastModified]' \
    --output table > state-versions.log
```

## Disaster Recovery

For complete disaster:

1. **Restore from snapshot**
2. **Re-run Terraform from backup state**
3. **Re-initialize databases**
4. **Update application configurations**
5. **Verify data integrity**

## Useful Commands

```bash
# List all state versions
aws s3api list-object-versions \
    --bucket terraform-state-rds-platform-dev \
    --prefix rds-platform/dev/terraform.tfstate

# Download specific state version
aws s3api get-object \
    --bucket terraform-state-rds-platform-dev \
    --key rds-platform/dev/terraform.tfstate \
    --version-id <version-id> \
    state.json

# List RDS snapshots
aws rds describe-db-snapshots \
    --db-instance-identifier rds-platform-dev-postgres

# Create manual snapshot
aws rds create-db-snapshot \
    --db-instance-identifier rds-platform-dev-postgres \
    --db-snapshot-identifier manual-snapshot-$(date +%Y%m%d-%H%M%S)
```

## Conclusion

Always prioritize:
1. Data integrity
2. Service availability
3. Security
4. Documentation

Regularly review and update this rollback strategy based on incidents and learnings.
