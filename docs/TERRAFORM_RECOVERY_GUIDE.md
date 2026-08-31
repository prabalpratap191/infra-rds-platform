# Terraform Recovery Guide

## Issue Summary

Your Terraform apply failed due to two critical issues:

1. **Provider Inconsistent Final Plan Error** - Caused by `timestamp()` in default tags
2. **KMS Key Not Found Error** - Backend references non-existent KMS alias
3. **State File Corruption Risk** - Local `errored.tfstate` file created

---

## ✅ Fixes Applied

### 1. Removed Dynamic timestamp() from Provider Tags

**File**: `terraform/providers.tf`

**Problem**: The `timestamp()` function generates a new value on every apply, causing Terraform to detect unexpected tag changes during the apply phase.

**Solution**: Removed `timestamp()` from `LastUpdated` tag and removed optional tags that are causing inconsistency:
- ❌ Removed: `Owner`, `CostCenter`, `Repository`, `LastUpdated`
- ✅ Kept: `Environment`, `Project`, `ManagedBy`

**Why**: These tags are still available at the resource level through `local.common_tags` in `main.tf`.

### 2. Fixed Backend KMS Configuration

**File**: `terraform/backend.tf`

**Problem**: Referenced KMS key `alias/terraform-state-key` doesn't exist in AWS account.

**Solution**: 
- Removed `kms_key_id` parameter (S3 will use default AES256 encryption)
- Replaced deprecated `dynamodb_table` with `use_lockfile`
- Removed `versioning` (not a valid backend parameter - versioning is configured on the S3 bucket itself)

---

## 🚨 Critical Recovery Steps

### Step 1: Reinitialize Terraform Backend

Since we changed the backend configuration, you **must** reinitialize:

```bash
cd terraform
terraform init -reconfigure
```

**Expected Output**: 
```
Initializing the backend...
Successfully configured the backend "s3"!
```

### Step 2: Handle the Errored State File

⚠️ **IMPORTANT**: You have a local `errored.tfstate` file that must be handled carefully.

#### Option A: Push Errored State (If No Other Changes)

If no one else has modified the infrastructure:

```bash
# Verify the errored state is valid
terraform state list -state=errored.tfstate

# Push it to the backend
terraform state push errored.tfstate

# Verify sync
terraform state list
```

#### Option B: Fresh Plan (Recommended for Safety)

If uncertain about state consistency:

```bash
# Backup the errored state
cp errored.tfstate errored.tfstate.backup

# Pull latest state from backend
terraform state pull > current.tfstate

# Compare states
diff errored.tfstate current.tfstate

# If similar, delete errored state
rm errored.tfstate

# Run new plan
terraform plan -out=tfplan
```

### Step 3: Clean Plan and Apply

```bash
# Generate a fresh plan
terraform plan -out=tfplan

# Review the plan carefully
terraform show tfplan

# Apply if plan looks correct
terraform apply tfplan
```

---

## 🔍 Verification Checklist

After recovery, verify:

- [ ] `terraform init -reconfigure` completed successfully
- [ ] No `errored.tfstate` file remains (or it has been pushed/backed up)
- [ ] `terraform plan` shows no unexpected tag changes on existing resources
- [ ] `terraform plan` shows only **6 resources to add** (matching your original intent):
  - 6 secrets (1 master + 5 microservices)
  - RDS subnet group
  - Security group
  - (Plus RDS instance and other dependent resources)
- [ ] No "Provider produced inconsistent final plan" errors
- [ ] State is being saved to S3 successfully

---

## 🛡️ Prevention - Best Practices

### 1. Never Use Non-Deterministic Functions in Tags

❌ **Avoid**:
```hcl
default_tags {
  tags = {
    LastUpdated = timestamp()  # NEVER do this
    RandomValue = uuid()       # NEVER do this
  }
}
```

✅ **Use Instead**:
```hcl
# Option 1: Static tags in provider
default_tags {
  tags = {
    Environment = var.environment
    Project     = "RDS-Platform"
    ManagedBy   = "Terraform"
  }
}

# Option 2: Add dynamic tags ONLY at resource level (not provider level)
resource "aws_instance" "example" {
  tags = merge(
    var.common_tags,
    {
      LastUpdated = formatdate("YYYY-MM-DD", timestamp())  # OK at resource level
    }
  )
}
```

### 2. KMS Key Prerequisites

If you want to use KMS encryption for state (optional but recommended for production):

```bash
# Create KMS key
KEY_ID=$(aws kms create-key --description "Terraform state encryption key" \
  --query 'KeyMetadata.KeyId' --output text)

# Create alias
aws kms create-alias --alias-name alias/terraform-state-key \
  --target-key-id $KEY_ID

# Update backend.tf
# Add back: kms_key_id = "alias/terraform-state-key"
```

### 3. Backend Prerequisites Checklist

Before running Terraform with S3 backend:

```bash
# 1. Create S3 bucket
aws s3api create-bucket \
  --bucket terraform-state-rds-platform-dev \
  --region us-east-1

# 2. Enable versioning (for state recovery)
aws s3api put-bucket-versioning \
  --bucket terraform-state-rds-platform-dev \
  --versioning-configuration Status=Enabled

# 3. Enable encryption (AES256 by default)
aws s3api put-bucket-encryption \
  --bucket terraform-state-rds-platform-dev \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

# 4. Block public access
aws s3api put-public-access-block \
  --bucket terraform-state-rds-platform-dev \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# 5. Create DynamoDB table for state locking (if not using use_lockfile)
aws dynamodb create-table \
  --table-name terraform-state-lock-rds-platform \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

---

## 📞 Need Help?

If you encounter issues during recovery:

1. **Check Terraform version**: Ensure you're using >= 1.5.0
   ```bash
   terraform version
   ```

2. **Validate configuration**:
   ```bash
   terraform validate
   ```

3. **Enable debug logging**:
   ```bash
   export TF_LOG=DEBUG
   terraform plan
   ```

4. **Check AWS credentials**:
   ```bash
   aws sts get-caller-identity
   ```

---

## 📋 Summary

| Issue | Root Cause | Fix Applied |
|-------|-----------|-------------|
| Inconsistent plan error | `timestamp()` in default_tags | Removed dynamic function |
| KMS key not found | Non-existent KMS alias | Removed KMS config, using default S3 encryption |
| State save failure | Backend config error | Fixed backend.tf parameters |
| Deprecated parameter warning | `dynamodb_table` usage | Replaced with `use_lockfile` |

---

**Next Steps**:
1. Run `terraform init -reconfigure`
2. Handle `errored.tfstate` (Option A or B above)
3. Run `terraform plan -out=tfplan`
4. Review plan carefully
5. Run `terraform apply tfplan`

✅ Your infrastructure code is now fixed and ready for deployment!
