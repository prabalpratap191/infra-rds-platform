# EKS Security Group Configuration Fix

**Date**: 2026-08-31  
**Issue**: Invalid Security Group ID Error  
**Status**: ✅ Fixed

---

## 🔴 Error Encountered

```
Error: authorizing Security Group (sg-00f96022d17289520) Rule (sgrule-2385737399): 
operation error EC2: AuthorizeSecurityGroupIngress, https response error StatusCode: 400, 
RequestID: 2c53624b-d5c1-43a8-8cba-ae4b24858d34, 
api error InvalidGroupId.Malformed: Invalid id: "eks-cluster-sg*" (expecting "sg-...")

  with module.security_group.aws_security_group_rule.rds_ingress_eks,
  on modules/security-group/main.tf line 18, in resource "aws_security_group_rule" "rds_ingress_eks":
  18: resource "aws_security_group_rule" "rds_ingress_eks" {
```

---

## 🎯 Root Cause

**File**: `terraform/terraform.tfvars` (Line 19)

**Problem**:
```hcl
eks_security_group_id = "eks-cluster-sg*"  # ❌ This is a PATTERN, not an ID!
```

The value `"eks-cluster-sg*"` is a **wildcard pattern**, but AWS expects an actual security group ID in the format `sg-xxxxxxxxxxxxxxxxx`.

**Why this happened**:
- The terraform.tfvars file was created as a template
- The placeholder value `"eks-cluster-sg*"` was never replaced with the actual security group ID
- This is a **required variable** that must be configured before deployment

---

## ✅ Solution

### Fix Applied

**File**: `terraform/terraform.tfvars` (Line 19)

**Before**:
```hcl
eks_security_group_id = "eks-cluster-sg*"  # ❌ Invalid
```

**After**:
```hcl
eks_security_group_id = "sg-0b25d44dfad6b21f4"  # ✅ Valid EKS node SG
```

**Security Group Details**:
- **ID**: `sg-0b25d44dfad6b21f4`
- **Name**: `meracommerce-dev-cluster-node-20260831042918951900000003`
- **Description**: EKS node shared security group
- **Created**: 2026-08-31 (Most recent)

---

## 🔍 How to Find EKS Security Group ID

### Method 1: Automated Script (Recommended)

Run the provided helper script:

```bash
cd scripts
chmod +x find-eks-security-group.sh
./find-eks-security-group.sh
```

**Output Example**:
```
EKS Node Security Groups:
------------------------------------
sg-0b25d44dfad6b21f4 | meracommerce-dev-cluster-node-... | EKS node shared security group
sg-0d597d212e2d1323f | meracommerce-dev-node-...         | EKS node shared security group

Recommended (Most Recent) EKS Node Security Group:
sg-0b25d44dfad6b21f4  meracommerce-dev-cluster-node-20260831042918951900000003

Copy this command to update your terraform.tfvars:
  eks_security_group_id = "sg-0b25d44dfad6b21f4"
```

### Method 2: AWS Console

1. Go to **EC2 Console** → **Security Groups**
2. Filter by VPC: `vpc-04c700d412f86947c`
3. Look for security groups with description: **"EKS node shared security group"**
4. Choose the **most recent** one (check creation date)
5. Copy the **Security Group ID** (format: `sg-xxxxxxxxxxxxxxxxx`)

### Method 3: AWS CLI

```bash
# List all EKS node security groups in your VPC
aws ec2 describe-security-groups \
  --region us-east-1 \
  --filters "Name=vpc-id,Values=vpc-04c700d412f86947c" \
            "Name=description,Values=*EKS node*" \
  --query 'SecurityGroups[*].[GroupId,GroupName,Description]' \
  --output table

# Get the most recent one
aws ec2 describe-security-groups \
  --region us-east-1 \
  --filters "Name=vpc-id,Values=vpc-04c700d412f86947c" \
            "Name=description,Values=*EKS node*" \
  --query 'sort_by(SecurityGroups, &GroupName)[-1].GroupId' \
  --output text
```

### Method 4: Terraform Data Source (Alternative Approach)

Instead of hardcoding the security group ID, you can use a data source to look it up dynamically:

**Add to `terraform/main.tf` or `terraform/data.tf`**:
```hcl
# Data source to find EKS node security group
data "aws_security_group" "eks_nodes" {
  vpc_id = var.vpc_id
  
  filter {
    name   = "description"
    values = ["EKS node shared security group"]
  }
  
  filter {
    name   = "tag:aws:eks:cluster-name"
    values = ["meracommerce-dev-cluster"]  # Replace with your cluster name
  }
}
```

**Update `terraform/main.tf`**:
```hcl
module "security_group" {
  source = "./modules/security-group"
  
  # ... other variables ...
  
  # Use data source instead of variable
  eks_security_group_id = data.aws_security_group.eks_nodes.id
}
```

---

## 📋 Available EKS Security Groups in Your VPC

From the AWS account scan, here are all EKS-related security groups:

| Security Group ID | Name | Type | Created |
|-------------------|------|------|----------|
| `sg-07eab55c6c38ad79d` | meracommerce-dev-cluster-cluster-... | EKS Cluster | 2026-08-31 |
| `sg-0b25d44dfad6b21f4` | meracommerce-dev-cluster-node-... | **EKS Node** | **2026-08-31** ✅ |
| `sg-0b5673d274df4dc70` | meracommerce-dev-cluster-... | EKS Cluster | 2026-08-20 |
| `sg-0d597d212e2d1323f` | meracommerce-dev-node-... | EKS Node | 2026-08-20 |

**Recommendation**: Use `sg-0b25d44dfad6b21f4` (most recent EKS node security group)

**Why EKS Node SG (not Cluster SG)**:
- **EKS Node Security Group**: Attached to EC2 worker nodes that run your pods
- **EKS Cluster Security Group**: Attached to the EKS control plane
- For **RDS access from pods**, you need the **node security group** because:
  - Pods run on worker nodes
  - Network traffic originates from worker node IPs
  - RDS ingress rule must allow traffic from worker nodes

---

## ✅ Verification Steps

### 1. Verify Security Group Exists

```bash
aws ec2 describe-security-groups \
  --group-ids sg-0b25d44dfad6b21f4 \
  --region us-east-1 \
  --query 'SecurityGroups[0].[GroupId,GroupName,VpcId,Description]' \
  --output table
```

**Expected Output**:
```
------------------------------------------
|        DescribeSecurityGroups          |
+----------------------+-----------------+
|  sg-0b25d44dfad6b21f4 |                |
|  meracommerce-dev-cluster-node-...     |
|  vpc-04c700d412f86947c |                |
|  EKS node shared security group        |
+----------------------+-----------------+
```

### 2. Validate Terraform Configuration

```bash
cd terraform
terraform validate
```

**Expected Output**:
```
Success! The configuration is valid.
```

### 3. Test Plan

```bash
terraform plan -out=tfplan
```

**What to look for**:
- ✅ No "InvalidGroupId.Malformed" errors
- ✅ Security group rule creation planned
- ✅ All modules initialize successfully

---

## 🚀 Next Steps

### 1. Commit the Fix

```bash
git add terraform/terraform.tfvars scripts/find-eks-security-group.sh docs/EKS_SECURITY_GROUP_FIX.md
git commit -m "fix: replace wildcard EKS security group pattern with actual ID

- Replace 'eks-cluster-sg*' with actual SG ID: sg-0b25d44dfad6b21f4
- Add script to discover EKS security groups automatically
- Add documentation for EKS security group configuration

Fixes: InvalidGroupId.Malformed error during security group rule creation"
git push
```

### 2. Retry Deployment

**Option A: Local Test** (Recommended)
```bash
cd terraform
terraform init -reconfigure
terraform plan -out=tfplan
# Review the plan carefully
terraform apply tfplan
```

**Option B: Jenkins Pipeline**
- Trigger pipeline with:
  - **ACTION**: `apply`
  - **ENVIRONMENT**: `dev`
- Monitor for successful completion

---

## 🛡️ Best Practices

### 1. Always Use Actual AWS Resource IDs

❌ **Don't use**:
- Wildcards: `"eks-cluster-sg*"`
- Patterns: `"*node*"`
- Placeholders: `"REPLACE_ME"`
- Names: `"my-security-group"` (use IDs instead)

✅ **Do use**:
- Actual IDs: `"sg-0b25d44dfad6b21f4"`
- Data sources: `data.aws_security_group.eks_nodes.id`
- SSM Parameters: `data.aws_ssm_parameter.eks_sg_id.value`

### 2. Document Required Variables

Create a `terraform/README.md` with:
```markdown
## Required Variables

Before running terraform, set these required variables in `terraform.tfvars`:

- `vpc_id`: Your VPC ID (format: vpc-xxxxxxxxxxxxxxxxx)
- `private_subnet_ids`: List of at least 2 private subnet IDs
- `eks_security_group_id`: EKS node security group ID (format: sg-xxxxxxxxxxxxxxxxx)
  - Find it: Run `scripts/find-eks-security-group.sh`
  - Or: AWS Console → EC2 → Security Groups → Filter "EKS node"
```

### 3. Use Terraform Data Sources for Dynamic Lookups

Instead of hardcoding IDs, use data sources:

```hcl
# Find VPC by tag
data "aws_vpc" "main" {
  tags = {
    Name = "main-vpc"
  }
}

# Find subnets by tag
data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }
  
  tags = {
    Tier = "private"
  }
}

# Use in configuration
vpc_id             = data.aws_vpc.main.id
private_subnet_ids = data.aws_subnets.private.ids
```

### 4. Pre-Deployment Validation Script

Create a validation script to check required resources:

```bash
#!/bin/bash
# validate-resources.sh

VPC_ID="vpc-04c700d412f86947c"
EKS_SG_ID="sg-0b25d44dfad6b21f4"

# Check VPC exists
aws ec2 describe-vpcs --vpc-ids "$VPC_ID" &>/dev/null || {
  echo "Error: VPC $VPC_ID not found"
  exit 1
}

# Check security group exists
aws ec2 describe-security-groups --group-ids "$EKS_SG_ID" &>/dev/null || {
  echo "Error: Security Group $EKS_SG_ID not found"
  exit 1
}

echo "✅ All resources validated"
```

---

## 📊 Impact Analysis

### Resources Affected

| Resource | Impact | Status |
|----------|--------|--------|
| `aws_security_group_rule.rds_ingress_eks` | Fixed - will now create successfully | ✅ |
| RDS instance | Can now receive connections from EKS pods | ✅ |
| All other resources | No impact | ✅ |

### Testing Required

After deployment:

1. **Test RDS connectivity from EKS pod**:
   ```bash
   kubectl run -it --rm postgres-test --image=postgres:15 --restart=Never -- \
     psql -h <rds-endpoint> -U postgres -d postgres
   ```

2. **Verify security group rule**:
   ```bash
   aws ec2 describe-security-group-rules \
     --filters "Name=group-id,Values=sg-00f96022d17289520" \
     --query 'SecurityGroupRules[?IsEgress==`false`]' \
     --output table
   ```

---

## 📚 Additional Resources

- **Helper Script**: [scripts/find-eks-security-group.sh](../scripts/find-eks-security-group.sh)
- **Terraform Variables**: [terraform/variables.tf](../terraform/variables.tf)
- **Security Group Module**: [terraform/modules/security-group/main.tf](../terraform/modules/security-group/main.tf)
- **Deployment Guide**: [deployment-guide.md](deployment-guide.md)

---

**Summary**: The invalid security group ID has been replaced with the actual EKS node security group ID. Deployment should now proceed successfully.

**Status**: ✅ Fixed  
**Ready to Deploy**: YES  
**Risk Level**: LOW (configuration fix only)
