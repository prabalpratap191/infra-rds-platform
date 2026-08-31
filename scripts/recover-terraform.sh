#!/bin/bash
# Terraform Recovery Script
# This script helps recover from the failed Terraform apply

set -e  # Exit on error

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Terraform Recovery Script${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if we're in the terraform directory
if [ ! -f "backend.tf" ]; then
    echo -e "${YELLOW}Navigating to terraform directory...${NC}"
    cd terraform
fi

# Step 1: Check for errored state file
echo -e "${YELLOW}Step 1: Checking for errored state file...${NC}"
if [ -f "errored.tfstate" ]; then
    echo -e "${RED}Found errored.tfstate file!${NC}"
    echo -e "${YELLOW}Creating backup...${NC}"
    cp errored.tfstate errored.tfstate.backup.$(date +%Y%m%d_%H%M%S)
    echo -e "${GREEN}Backup created${NC}"
    
    read -p "Do you want to push this state to the backend? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Pushing errored state to backend...${NC}"
        terraform state push errored.tfstate
        echo -e "${GREEN}State pushed successfully${NC}"
        rm errored.tfstate
    else
        echo -e "${YELLOW}Skipping state push. You can manually handle it later.${NC}"
        mv errored.tfstate errored.tfstate.manual_review
    fi
else
    echo -e "${GREEN}No errored state file found${NC}"
fi

echo ""

# Step 2: Reinitialize backend
echo -e "${YELLOW}Step 2: Reinitializing Terraform backend...${NC}"
terraform init -reconfigure

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Backend reinitialized successfully!${NC}"
else
    echo -e "${RED}Backend initialization failed!${NC}"
    exit 1
fi

echo ""

# Step 3: Validate configuration
echo -e "${YELLOW}Step 3: Validating Terraform configuration...${NC}"
terraform validate

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Configuration is valid!${NC}"
else
    echo -e "${RED}Configuration validation failed!${NC}"
    exit 1
fi

echo ""

# Step 4: Generate new plan
echo -e "${YELLOW}Step 4: Generating new Terraform plan...${NC}"
terraform plan -out=tfplan.recovered

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Plan generated successfully!${NC}"
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Recovery Complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Review the plan: terraform show tfplan.recovered"
    echo "2. If the plan looks correct, apply it: terraform apply tfplan.recovered"
    echo ""
    echo -e "${YELLOW}Expected resources to create:${NC}"
    echo "  - 1 Master database secret"
    echo "  - 5 Microservice database secrets"
    echo "  - 1 DB subnet group"
    echo "  - 1 Security group"
    echo "  - 1 RDS instance"
    echo "  - CloudWatch alarms"
    echo ""
else
    echo -e "${RED}Plan generation failed!${NC}"
    echo -e "${YELLOW}Please review the errors and check:${NC}"
    echo "  - AWS credentials are valid"
    echo "  - Required variables are set"
    echo "  - Backend S3 bucket exists"
    exit 1
fi

echo -e "${GREEN}Script completed successfully!${NC}"
