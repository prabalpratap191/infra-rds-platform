# Pre-Deployment Checklist

**Project**: RDS Platform Infrastructure  
**Environment**: dev  
**Date**: 2026-08-31

---

## ✅ Code Fixes Verification

### 1. Configuration Files Fixed

- [ ] **terraform/providers.tf**
  - [ ] `timestamp()` removed from default_tags
  - [ ] Only static/variable tags remain: `Environment`, `Project`, `ManagedBy`
  - [ ] No non-deterministic functions in provider configuration

- [ ] **terraform/backend.tf**
  - [ ] KMS key reference removed
  - [ ] `use_lockfile = true` added
  - [ ] `dynamodb_table` parameter removed
  - [ ] `versioning` parameter removed
  - [ ] `encrypt = true` retained (using S3 default AES256)

### 2. Documentation Created

- [ ] [TERRAFORM_RECOVERY_GUIDE.md](docs/TERRAFORM_RECOVERY_GUIDE.md) exists
- [ ] [recover-terraform.sh](scripts/recover-terraform.sh) exists and is executable
- [ ] [QUICK_FIX.md](QUICK_FIX.md) exists
- [ ] [terraform-fix-summary.md](terraform-fix-summary.md) exists
- [ ] [FIXES.md](docs/FIXES.md) updated with new fixes

---

## 🔧 Local Validation (Optional but Recommended)

### Prerequisites Check

- [ ] AWS CLI installed: `aws --version`
- [ ] Terraform installed: `terraform version` (>= 1.5.0)
- [ ] AWS credentials configured: `aws sts get-caller-identity`
- [ ] Correct AWS account: 230476794540
- [ ] Correct region: us-east-1

### Backend Prerequisites

- [ ] S3 bucket exists: `terraform-state-rds-platform-dev`
  ```bash
  aws s3 ls s3://terraform-state-rds-platform-dev
  ```

- [ ] S3 bucket versioning enabled:
  ```bash
  aws s3api get-bucket-versioning --bucket terraform-state-rds-platform-dev
  ```

- [ ] S3 bucket encryption enabled:
  ```bash
  aws s3api get-bucket-encryption --bucket terraform-state-rds-platform-dev
  ```

### Local Test (Optional)

```bash
cd terraform

# 1. Initialize backend
terraform init -reconfigure

# 2. Validate configuration
terraform validate

# 3. Format check
terraform fmt -check -recursive

# 4. Generate plan
terraform plan -out=tfplan.local

# 5. Review plan
terraform show tfplan.local
```

**Expected Results**:
- [ ] No "Provider produced inconsistent final plan" errors
- [ ] No KMS key errors
- [ ] No deprecated parameter warnings
- [ ] Plan shows ~30 resources to create
- [ ] Plan shows 0 resources to change
- [ ] Plan shows 0 resources to destroy

---

## 🐛 Error State Cleanup

### Check for Errored State File

- [ ] Navigate to terraform directory: `cd terraform`
- [ ] Check for errored state: `ls -la errored.tfstate*`

**If errored.tfstate exists**:

- [ ] **Option A**: Backup and ignore
  ```bash
  mv errored.tfstate errored.tfstate.backup.$(date +%Y%m%d)
  ```

- [ ] **Option B**: Push to backend (if confident)
  ```bash
  terraform state push errored.tfstate
  rm errored.tfstate
  ```

---

## 📦 Git Commit & Push

### Files to Commit

```bash
git status
```

**Modified**:
- [ ] `terraform/providers.tf`
- [ ] `terraform/backend.tf`
- [ ] `docs/FIXES.md`

**New**:
- [ ] `docs/TERRAFORM_RECOVERY_GUIDE.md`
- [ ] `scripts/recover-terraform.sh`
- [ ] `QUICK_FIX.md`
- [ ] `terraform-fix-summary.md`
- [ ] `PRE_DEPLOYMENT_CHECKLIST.md` (this file)

### Commit Commands

```bash
# Stage all changes
git add terraform/providers.tf terraform/backend.tf
git add docs/TERRAFORM_RECOVERY_GUIDE.md docs/FIXES.md
git add scripts/recover-terraform.sh
git add QUICK_FIX.md terraform-fix-summary.md PRE_DEPLOYMENT_CHECKLIST.md

# Commit with descriptive message
git commit -m "fix: resolve Terraform provider inconsistent plan and KMS backend errors

- Remove timestamp() from provider default_tags to fix inconsistent plan
- Remove non-existent KMS key reference from backend config
- Replace deprecated dynamodb_table with use_lockfile
- Add comprehensive recovery documentation and scripts

Fixes: terraform apply failure in Jenkins pipeline
Issue: Provider produced inconsistent final plan errors"

# Push to remote
git push origin <your-branch>
```

---

## 🚀 Jenkins Pipeline Execution

### Before Triggering Pipeline

- [ ] Code committed and pushed to repository
- [ ] Jenkins has latest code (branch indexing complete)
- [ ] AWS credentials configured in Jenkins: `aws-credentials`
- [ ] Jenkins agent has Terraform capability

### Pipeline Parameters

- [ ] **ACTION**: Select `apply`
- [ ] **ENVIRONMENT**: Select `dev`
- [ ] **Optional**: Review Jenkinsfile for any changes needed

### During Pipeline Execution - Monitor for:

**✅ Success Indicators**:
- [ ] Terraform init completes without errors
- [ ] No "Provider produced inconsistent final plan" errors
- [ ] No "KMS.NotFoundException" errors
- [ ] No deprecated parameter warnings
- [ ] State saves to S3 successfully
- [ ] All resources created as planned
- [ ] Pipeline stage: "Terraform Apply" = SUCCESS

**❌ Failure Indicators to Watch**:
- [ ] Any "inconsistent final plan" errors
- [ ] KMS-related errors
- [ ] State persistence failures
- [ ] Resource creation errors

### Post-Deployment Verification

- [ ] Check AWS Console:
  - [ ] RDS instance created
  - [ ] Security group created
  - [ ] Secrets Manager secrets created (6 total)
  - [ ] CloudWatch alarms created

- [ ] Verify Terraform state:
  ```bash
  terraform state list
  ```

- [ ] Test database connectivity (from bastion/EKS):
  ```bash
  psql -h <rds-endpoint> -U postgres -d postgres
  ```

---

## 🚨 Rollback Plan (If Needed)

If deployment fails:

### Immediate Actions

1. **Capture Error Logs**:
   - Save Jenkins console output
   - Run locally: `export TF_LOG=DEBUG && terraform plan`

2. **Check State**:
   ```bash
   terraform state pull > current-state.json
   ```

3. **Destroy Partial Resources** (if needed):
   ```bash
   terraform destroy -auto-approve
   ```

### Recovery Options

- [ ] **Option A**: Review error and retry
  - Identify specific error
  - Apply targeted fix
  - Rerun pipeline

- [ ] **Option B**: Rollback code changes
  ```bash
  git revert <commit-hash>
  git push
  ```

- [ ] **Option C**: Manual cleanup
  - Delete resources via AWS Console
  - Clean up state file
  - Start fresh

---

## 📞 Emergency Contacts & Resources

### Documentation References

- **Recovery Guide**: [docs/TERRAFORM_RECOVERY_GUIDE.md](docs/TERRAFORM_RECOVERY_GUIDE.md)
- **Quick Fix**: [QUICK_FIX.md](QUICK_FIX.md)
- **Fix Summary**: [terraform-fix-summary.md](terraform-fix-summary.md)
- **All Fixes**: [docs/FIXES.md](docs/FIXES.md)
- **Deployment Guide**: [docs/deployment-guide.md](docs/deployment-guide.md)

### Useful Commands

```bash
# Check Terraform version
terraform version

# Validate configuration
terraform validate

# Format check
terraform fmt -check

# Show current state
terraform state list

# Show specific resource
terraform state show <resource>

# Refresh state
terraform refresh

# Check AWS credentials
aws sts get-caller-identity

# List S3 state versions
aws s3api list-object-versions \
  --bucket terraform-state-rds-platform-dev \
  --prefix rds-platform/terraform.tfstate
```

---

## ✅ Final Sign-Off

### Checklist Complete

- [ ] All code fixes verified
- [ ] Local validation passed (if performed)
- [ ] Errored state handled
- [ ] Code committed and pushed
- [ ] Jenkins pipeline configured
- [ ] Monitoring plan in place
- [ ] Rollback plan ready

### Deployment Authorization

- [ ] **Ready to Deploy**: YES / NO
- [ ] **Confidence Level**: High / Medium / Low
- [ ] **Risk Assessment**: Low (configuration-only changes)

**Authorized By**: _________________  
**Date**: 2026-08-31  
**Time**: _________________

---

## 🎉 Post-Deployment

### After Successful Deployment

- [ ] Update deployment log
- [ ] Notify team of successful deployment
- [ ] Archive Jenkins console output
- [ ] Document any issues encountered
- [ ] Update runbook if needed

### Lessons Learned

- [ ] Document what worked well
- [ ] Document what could be improved
- [ ] Update CI/CD pipeline if needed
- [ ] Share knowledge with team

---

**Good luck with the deployment! 🚀**
