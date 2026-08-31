#!/bin/bash
# Script to find EKS security group IDs for RDS configuration

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}EKS Security Group Finder${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Get VPC ID from terraform.tfvars or ask user
VPC_ID="vpc-04c700d412f86947c"
REGION="us-east-1"

echo -e "${YELLOW}Searching for EKS security groups in VPC: ${VPC_ID}${NC}"
echo -e "${YELLOW}Region: ${REGION}${NC}"
echo ""

# Find EKS cluster security groups
echo -e "${BLUE}EKS Cluster Security Groups:${NC}"
aws ec2 describe-security-groups \
  --region "$REGION" \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=description,Values=*EKS cluster*" \
  --query 'SecurityGroups[*].[GroupId,GroupName,Description]' \
  --output table

echo ""

# Find EKS node security groups
echo -e "${BLUE}EKS Node Security Groups:${NC}"
aws ec2 describe-security-groups \
  --region "$REGION" \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=description,Values=*EKS node*" \
  --query 'SecurityGroups[*].[GroupId,GroupName,Description]' \
  --output table

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}How to use these security groups:${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}For RDS configuration, you need the EKS NODE security group ID${NC}"
echo -e "${YELLOW}(Description contains 'EKS node shared security group')${NC}"
echo ""
echo -e "Update ${BLUE}terraform/terraform.tfvars${NC} with the correct security group ID:"
echo ""
echo -e "  eks_security_group_id = \"${GREEN}sg-XXXXXXXXXXXXXXXXX${NC}\""
echo ""
echo -e "${YELLOW}Choose the MOST RECENT EKS node security group from the list above.${NC}"
echo ""

# Optionally, get the most recent one automatically
echo -e "${BLUE}Recommended (Most Recent) EKS Node Security Group:${NC}"
MOST_RECENT_SG=$(aws ec2 describe-security-groups \
  --region "$REGION" \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=description,Values=*EKS node*" \
  --query 'sort_by(SecurityGroups, &GroupName)[-1].[GroupId,GroupName]' \
  --output text)

if [ -n "$MOST_RECENT_SG" ]; then
    echo -e "${GREEN}$MOST_RECENT_SG${NC}"
    echo ""
    echo -e "${YELLOW}Copy this command to update your terraform.tfvars:${NC}"
    SG_ID=$(echo "$MOST_RECENT_SG" | awk '{print $1}')
    echo ""
    echo -e "  ${GREEN}eks_security_group_id = \"$SG_ID\"${NC}"
    echo ""
else
    echo -e "${RED}No EKS node security groups found!${NC}"
    echo -e "${YELLOW}Please create an EKS cluster first or manually specify the security group ID.${NC}"
fi

echo -e "${GREEN}Done!${NC}"
