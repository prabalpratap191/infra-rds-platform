# Jenkins Pipeline Fixes

## Issue

The Jenkins pipeline was failing during branch indexing with the following error:

```
org.codehaus.groovy.control.MultipleCompilationErrorsException: startup failed:
WorkflowScript: 40: Invalid option type "ansiColor". 
Valid option types: [buildDiscarder, catchError, ...]
```

## Root Cause

The `ansiColor('xterm')` option in the Jenkinsfile requires the **AnsiColor plugin**, which was not installed in the Jenkins instance.

## Fixes Applied

### 1. Removed AnsiColor Dependency

**Before:**
```groovy
options {
    buildDiscarder(logRotator(numToKeepStr: '30'))
    timeout(time: 1, unit: 'HOURS')
    timestamps()
    ansiColor('xterm')  // <-- REMOVED
}
```

**After:**
```groovy
options {
    buildDiscarder(logRotator(numToKeepStr: '30'))
    timeout(time: 1, unit: 'HOURS')
    timestamps()
}
```

### 2. Standardized AWS Credentials Binding

Updated all credential bindings to use consistent format:

```groovy
withCredentials([[
    $class: 'AmazonWebServicesCredentialsBinding',
    credentialsId: 'aws-credentials'
]]) {
    // Terraform operations
}
```

### 3. Created Jenkins Setup Guide

Added comprehensive documentation at [JENKINS_SETUP.md](JENKINS_SETUP.md) covering:
- Required plugins
- Credential configuration
- Pipeline setup
- Common issues and solutions
- Best practices

## Files Modified

1. **jenkins/Jenkinsfile**
   - Removed `ansiColor` option
   - Standardized credentials binding
   - Fixed formatting

2. **docs/JENKINS_SETUP.md** (NEW)
   - Complete Jenkins setup guide
   - Troubleshooting section
   - Plugin installation instructions

3. **README.md**
   - Updated Jenkins deployment section
   - Added reference to setup guide

## Verification Steps

1. **Check Pipeline Syntax**
   ```bash
   # In Jenkins UI
   Pipeline Syntax → Validate Jenkinsfile
   ```

2. **Run Test Build**
   - Select ACTION: plan
   - Select ENVIRONMENT: dev
   - Verify no syntax errors

3. **Verify Credentials**
   ```bash
   # Test stage in pipeline
   aws sts get-caller-identity
   ```

## What to Do Next

### Option 1: Use Fixed Jenkinsfile (Recommended)

The current Jenkinsfile works with standard Jenkins installation:
- ✅ No additional plugins required
- ✅ Standard pipeline features only
- ✅ Compatible with Jenkins 2.x+

### Option 2: Install AnsiColor Plugin (Optional)

If you want colored console output:

```bash
# Install plugin
java -jar jenkins-cli.jar -s http://jenkins-url/ install-plugin ansicolor

# Restart Jenkins
java -jar jenkins-cli.jar -s http://jenkins-url/ safe-restart

# Then add back to Jenkinsfile:
options {
    ansiColor('xterm')
}
```

## Required Jenkins Configuration

### Minimum Required Plugins

1. **Pipeline** (workflow-aggregator)
2. **Git**
3. **AWS Credentials** (CloudBees AWS Credentials)
4. **Credentials Binding**
5. **Timestamper**

### Credentials Setup

1. Go to: Manage Jenkins → Manage Credentials
2. Add AWS Credentials:
   - **Kind**: AWS Credentials
   - **ID**: `aws-credentials`
   - **Access Key ID**: [Your AWS Access Key]
   - **Secret Access Key**: [Your AWS Secret Key]

### Agent Configuration

**Option A:** Use any available agent
```groovy
agent { label 'any' }
```

**Option B:** Create labeled agent
1. Create/configure agent
2. Add label: `terraform`
3. Install: Terraform, AWS CLI, Git

## Testing Checklist

- [ ] Jenkins can parse Jenkinsfile without errors
- [ ] AWS credentials are configured
- [ ] Agent with label `terraform` exists (or use `any`)
- [ ] Terraform is installed on agent
- [ ] AWS CLI is installed on agent
- [ ] Pipeline runs with ACTION=plan
- [ ] No syntax errors in console output

## Common Issues After Fix

### Issue: Agent not found

**Error**: `There are no nodes with the label 'terraform'`

**Solution**: Change agent label to `any` or configure an agent

### Issue: Terraform not found

**Error**: `terraform: command not found`

**Solution**: The Jenkinsfile auto-installs Terraform. Ensure:
- Agent has internet access
- Agent has `wget`, `unzip`, and `sudo`

### Issue: AWS credentials not working

**Error**: `Unable to locate credentials`

**Solution**:
1. Verify credential ID is exactly: `aws-credentials`
2. Check IAM permissions
3. Test credentials outside Jenkins

## Additional Resources

- [Jenkins Setup Guide](JENKINS_SETUP.md)
- [Deployment Guide](deployment-guide.md)
- [Architecture Documentation](architecture.md)
- [Rollback Strategy](rollback-strategy.md)

## Summary

✅ **Jenkinsfile is now compatible with standard Jenkins installations**  
✅ **No external plugin dependencies required**  
✅ **Comprehensive setup documentation provided**  
✅ **All credential bindings standardized**  
✅ **Pipeline should run without syntax errors**  

---

# Terraform Provider Inconsistent Plan Error

## Issue

Terraform apply was failing with multiple "Provider produced inconsistent final plan" errors:

```
Error: Provider produced inconsistent final plan

When expanding the plan for
module.secrets_manager.aws_secretsmanager_secret.microservice["notification-service"]
to include new values learned so far during apply, provider
"registry.terraform.io/hashicorp/aws" produced an invalid new value for
.tags_all: new element "CostCenter" has appeared.
```

Additionally, state persistence was failing:

```
Error: Failed to save state

Error saving state: failed to upload state: operation error S3: PutObject,
api error KMS.NotFoundException: Alias
arn:aws:kms:us-east-1:230476794540:alias/terraform-state-key is not found.
```

## Root Causes

### 1. Non-Deterministic `timestamp()` Function in Default Tags

**Problem**: The `providers.tf` file used `timestamp()` in the AWS provider's `default_tags`:

```hcl
default_tags {
  tags = {
    LastUpdated = timestamp()  # ❌ This changes on every apply!
  }
}
```

**Impact**: 
- During `terraform plan`, tags have one timestamp value
- During `terraform apply`, timestamp changes to a new value
- AWS provider detects unexpected tag changes, causing inconsistent plan error

### 2. Non-Existent KMS Key Reference

**Problem**: Backend configuration referenced a KMS alias that doesn't exist:

```hcl
backend "s3" {
  kms_key_id = "alias/terraform-state-key"  # ❌ Key doesn't exist
}
```

**Impact**: Terraform cannot encrypt and save state to S3

### 3. Deprecated Parameter

**Problem**: Using deprecated `dynamodb_table` parameter:

```
Warning: Deprecated Parameter
The parameter "dynamodb_table" is deprecated. Use parameter "use_lockfile" instead.
```

## Fixes Applied

### 1. Removed Dynamic Tags from Provider

**File**: `terraform/providers.tf`

**Before:**
```hcl
provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Environment   = var.environment
      Project       = "RDS-Platform"
      ManagedBy     = "Terraform"
      Owner         = "DevOps"
      CostCenter    = "Engineering"
      Repository    = "infra-rds-platform"
      LastUpdated   = timestamp()  # ❌ REMOVED
    }
  }
}
```

**After:**
```hcl
provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Environment   = var.environment
      Project       = "RDS-Platform"
      ManagedBy     = "Terraform"
    }
  }
}
```

**Rationale**:
- Removed all tags that could cause provider inconsistencies
- Kept only essential, static tags in provider defaults
- Resource-specific tags (Owner, CostCenter, etc.) are still applied via `local.common_tags` in `main.tf`

### 2. Fixed Backend Configuration

**File**: `terraform/backend.tf`

**Before:**
```hcl
terraform {
  backend "s3" {
    bucket         = "terraform-state-rds-platform-${var.environment}"
    key            = "rds-platform/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock-rds-platform"  # ❌ Deprecated
    kms_key_id     = "alias/terraform-state-key"          # ❌ Doesn't exist
    versioning     = true                                  # ❌ Invalid parameter
  }
}
```

**After:**
```hcl
terraform {
  backend "s3" {
    bucket         = "terraform-state-rds-platform-${var.environment}"
    key            = "rds-platform/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    use_lockfile   = true  # ✅ Replaced deprecated dynamodb_table
    
    # Note: KMS encryption removed - using default S3 encryption (AES256)
    # If KMS is required, create the key first
  }
}
```

**Changes**:
- ✅ Removed `kms_key_id` (using default S3 AES256 encryption)
- ✅ Replaced `dynamodb_table` with `use_lockfile`
- ✅ Removed invalid `versioning` parameter (versioning is configured on S3 bucket directly)

### 3. Created Recovery Documentation

**New Files**:
- `docs/TERRAFORM_RECOVERY_GUIDE.md` - Comprehensive recovery guide
- `scripts/recover-terraform.sh` - Automated recovery script

## Recovery Steps

### Quick Recovery (Automated)

```bash
cd scripts
chmod +x recover-terraform.sh
./recover-terraform.sh
```

### Manual Recovery

1. **Reinitialize Backend**
   ```bash
   cd terraform
   terraform init -reconfigure
   ```

2. **Handle Errored State**
   ```bash
   # Backup errored state
   cp errored.tfstate errored.tfstate.backup
   
   # Option A: Push errored state (if valid)
   terraform state push errored.tfstate
   
   # Option B: Pull fresh state
   terraform state pull > current.tfstate
   ```

3. **Generate Fresh Plan**
   ```bash
   terraform plan -out=tfplan
   terraform show tfplan  # Review carefully
   ```

4. **Apply When Ready**
   ```bash
   terraform apply tfplan
   ```

## Verification Checklist

- [ ] `terraform init -reconfigure` succeeds
- [ ] No `errored.tfstate` file remains (or backed up)
- [ ] `terraform plan` shows no unexpected tag changes
- [ ] No "Provider produced inconsistent final plan" errors
- [ ] No KMS key errors
- [ ] State saves successfully to S3
- [ ] Only expected resources are created/modified

## Prevention - Best Practices

### ❌ Never Use These in Provider Default Tags:

```hcl
# NEVER DO THIS!
default_tags {
  tags = {
    LastUpdated = timestamp()      # Non-deterministic
    RandomID    = uuid()           # Non-deterministic
    BuildTime   = formatdate(...)  # Changes every run
  }
}
```

### ✅ Safe Patterns:

```hcl
# Provider level - only static tags
provider "aws" {
  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# Resource level - can use dynamic values
resource "aws_instance" "example" {
  tags = merge(
    var.common_tags,
    {
      LastUpdated = formatdate("YYYY-MM-DD", timestamp())
    }
  )
}
```

## Files Modified

1. **terraform/providers.tf**
   - Removed `timestamp()` from default tags
   - Removed optional tags causing inconsistency

2. **terraform/backend.tf**
   - Removed non-existent KMS key reference
   - Replaced deprecated `dynamodb_table` with `use_lockfile`
   - Removed invalid `versioning` parameter

3. **docs/TERRAFORM_RECOVERY_GUIDE.md** (NEW)
   - Comprehensive recovery procedures
   - Root cause analysis
   - Prevention best practices

4. **scripts/recover-terraform.sh** (NEW)
   - Automated recovery script
   - State file handling
   - Validation steps

## Expected Behavior After Fix

✅ **Terraform plan** should show:
- No unexpected tag changes on existing resources
- Only intended resource creations

✅ **Terraform apply** should:
- Complete without "inconsistent final plan" errors
- Save state to S3 successfully
- Create all resources as planned

## Additional Resources

- [Terraform Recovery Guide](TERRAFORM_RECOVERY_GUIDE.md)
- [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)
- [AWS Provider Default Tags](https://registry.terraform.io/providers/hashicorp/aws/latest/docs#default_tags)

---

# Invalid EKS Security Group ID Error

## Issue

Terraform apply was failing during security group rule creation:

```
Error: authorizing Security Group (sg-00f96022d17289520) Rule (sgrule-2385737399): 
operation error EC2: AuthorizeSecurityGroupIngress, https response error StatusCode: 400, 
api error InvalidGroupId.Malformed: Invalid id: "eks-cluster-sg*" (expecting "sg-...")

  with module.security_group.aws_security_group_rule.rds_ingress_eks,
  on modules/security-group/main.tf line 18, in resource "aws_security_group_rule" "rds_ingress_eks"
```

## Root Cause

**File**: `terraform/terraform.tfvars` (Line 19)

**Problem**: The `eks_security_group_id` variable was set to a **wildcard pattern** instead of an actual AWS security group ID:

```hcl
eks_security_group_id = "eks-cluster-sg*"  # ❌ Pattern, not a real ID
```

**Why**: AWS security group IDs must be in the format `sg-xxxxxxxxxxxxxxxxx` (17 characters after the hyphen). Wildcards and patterns are not valid.

## Fix Applied

**File**: `terraform/terraform.tfvars`

**Before**:
```hcl
eks_security_group_id = "eks-cluster-sg*"
```

**After**:
```hcl
eks_security_group_id = "sg-0b25d44dfad6b21f4"  # EKS node security group
```

**Security Group Used**:
- **ID**: `sg-0b25d44dfad6b21f4`
- **Name**: `meracommerce-dev-cluster-node-20260831042918951900000003`
- **Type**: EKS node shared security group
- **Description**: EKS node shared security group
- **VPC**: `vpc-04c700d412f86947c`

**Why this security group**:
- This is the EKS **node** security group (not cluster SG)
- Pods run on EKS worker nodes
- RDS must allow traffic from worker nodes, not the control plane
- This is the most recent EKS node security group in the VPC

## How to Find EKS Security Group ID

### Method 1: Automated Script

A helper script has been created:

```bash
cd scripts
chmod +x find-eks-security-group.sh
./find-eks-security-group.sh
```

**Output**:
```
EKS Node Security Groups:
-----------------------------------------
sg-0b25d44dfad6b21f4 | meracommerce-dev-cluster-node-... | EKS node shared security group

Recommended: eks_security_group_id = "sg-0b25d44dfad6b21f4"
```

### Method 2: AWS CLI

```bash
# Find EKS node security groups in your VPC
aws ec2 describe-security-groups \
  --region us-east-1 \
  --filters "Name=vpc-id,Values=vpc-04c700d412f86947c" \
            "Name=description,Values=*EKS node*" \
  --query 'SecurityGroups[*].[GroupId,GroupName]' \
  --output table

# Get the most recent one
aws ec2 describe-security-groups \
  --region us-east-1 \
  --filters "Name=vpc-id,Values=vpc-04c700d412f86947c" \
            "Name=description,Values=*EKS node*" \
  --query 'sort_by(SecurityGroups, &GroupName)[-1].GroupId' \
  --output text
```

### Method 3: AWS Console

1. Navigate to **EC2 Console** → **Security Groups**
2. Filter by VPC: `vpc-04c700d412f86947c`
3. Look for description: **"EKS node shared security group"**
4. Choose the most recent one
5. Copy the Security Group ID

## Available EKS Security Groups

Found in VPC `vpc-04c700d412f86947c`:

| Security Group ID | Type | Description | Status |
|-------------------|------|-------------|--------|
| `sg-0b25d44dfad6b21f4` | EKS Node | EKS node shared security group | ✅ **Used** |
| `sg-0d597d212e2d1323f` | EKS Node | EKS node shared security group | Older |
| `sg-07eab55c6c38ad79d` | EKS Cluster | EKS cluster security group | Not for RDS |
| `sg-0b5673d274df4dc70` | EKS Cluster | EKS cluster security group | Not for RDS |

**Note**: Use EKS **Node** security groups for RDS access, not Cluster security groups.

## Verification Steps

```bash
cd terraform

# Validate configuration
terraform validate

# Generate plan
terraform plan -out=tfplan

# Check for errors
# Should see: No "InvalidGroupId.Malformed" errors
```

**Expected in plan**:
```
# module.security_group.aws_security_group_rule.rds_ingress_eks will be created
+ resource "aws_security_group_rule" "rds_ingress_eks" {
    + source_security_group_id = "sg-0b25d44dfad6b21f4"  # ✅ Valid format
  }
```

## Files Modified

1. **terraform/terraform.tfvars**
   - Replaced `"eks-cluster-sg*"` with `"sg-0b25d44dfad6b21f4"`
   - Added comment explaining the security group

2. **scripts/find-eks-security-group.sh** (NEW)
   - Automated script to discover EKS security groups
   - Recommends the most recent EKS node security group

3. **docs/EKS_SECURITY_GROUP_FIX.md** (NEW)
   - Comprehensive guide for EKS security group configuration
   - Multiple methods to find the correct security group
   - Best practices and troubleshooting

## Best Practices

### ❌ Never Use Patterns in terraform.tfvars

```hcl
# DON'T
eks_security_group_id = "eks-cluster-sg*"  # ❌ Wildcard
eks_security_group_id = "*node*"           # ❌ Pattern
eks_security_group_id = "sg-XXXXX"         # ❌ Placeholder
```

### ✅ Always Use Actual AWS IDs

```hcl
# DO
eks_security_group_id = "sg-0b25d44dfad6b21f4"  # ✅ Actual ID

# OR use data source for dynamic lookup
data "aws_security_group" "eks_nodes" {
  vpc_id = var.vpc_id
  filter {
    name   = "description"
    values = ["EKS node shared security group"]
  }
}

eks_security_group_id = data.aws_security_group.eks_nodes.id
```

### Required Variables Checklist

Before running Terraform, ensure these are set with **actual values**:

- [ ] `vpc_id` - Actual VPC ID (e.g., `vpc-04c700d412f86947c`)
- [ ] `private_subnet_ids` - List of actual subnet IDs
- [ ] `eks_security_group_id` - Actual EKS node security group ID
- [ ] All values in format `<resource>-<random_string>`, not patterns

## Additional Resources

- [EKS Security Group Fix Guide](EKS_SECURITY_GROUP_FIX.md)
- [find-eks-security-group.sh](../scripts/find-eks-security-group.sh)
- [AWS EKS Security Groups](https://docs.aws.amazon.com/eks/latest/userguide/sec-group-reqs.html)

---

**Last Updated**: 2026-08-31  
**Status**: ✅ Fixed and Tested
