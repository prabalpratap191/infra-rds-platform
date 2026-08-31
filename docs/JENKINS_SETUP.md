# Jenkins Setup Guide

## Prerequisites

### Required Jenkins Plugins

The following plugins must be installed in Jenkins:

1. **Pipeline** - Pipeline plugin for Jenkinsfile support
2. **Git** - Git integration
3. **AWS Steps** - AWS integration (`aws-credentials` binding)
4. **Credentials Binding** - Credential management
5. **Timestamper** - Timestamp support in console output

### Optional Plugins (Recommended)

- **AnsiColor** - For colored console output (if you want to enable it)
- **Blue Ocean** - Modern UI for pipelines
- **Pipeline: Stage View** - Better stage visualization

## Installing Required Plugins

### Via Jenkins UI

1. Go to **Manage Jenkins** → **Manage Plugins**
2. Click **Available** tab
3. Search and install:
   - Pipeline
   - Git plugin
   - CloudBees AWS Credentials
   - Credentials Binding Plugin
   - Timestamper
4. Restart Jenkins after installation

### Via Jenkins CLI

```bash
java -jar jenkins-cli.jar -s http://jenkins-url/ install-plugin \
    workflow-aggregator \
    git \
    aws-credentials \
    credentials-binding \
    timestamper
```

## Configuring AWS Credentials

### Step 1: Create IAM User for Jenkins

```bash
# Create IAM user
aws iam create-user --user-name jenkins-terraform-user

# Attach required policies
aws iam attach-user-policy \
    --user-name jenkins-terraform-user \
    --policy-arn arn:aws:iam::aws:policy/AmazonRDSFullAccess

aws iam attach-user-policy \
    --user-name jenkins-terraform-user \
    --policy-arn arn:aws:iam::aws:policy/AmazonVPCFullAccess

aws iam attach-user-policy \
    --user-name jenkins-terraform-user \
    --policy-arn arn:aws:iam::aws:policy/SecretsManagerReadWrite

aws iam attach-user-policy \
    --user-name jenkins-terraform-user \
    --policy-arn arn:aws:iam::aws:policy/CloudWatchFullAccess

# Create access key
aws iam create-access-key --user-name jenkins-terraform-user
```

Save the `AccessKeyId` and `SecretAccessKey`.

### Step 2: Add Credentials to Jenkins

1. Go to **Manage Jenkins** → **Manage Credentials**
2. Click **(global)** domain
3. Click **Add Credentials**
4. Select **AWS Credentials**
5. Fill in:
   - **ID**: `aws-credentials`
   - **Description**: AWS credentials for Terraform
   - **Access Key ID**: [Your Access Key]
   - **Secret Access Key**: [Your Secret Key]
6. Click **OK**

## Setting Up the Pipeline Job

### Step 1: Create Pipeline Job

1. Click **New Item**
2. Enter name: `rds-platform-deployment`
3. Select **Pipeline**
4. Click **OK**

### Step 2: Configure Pipeline

1. **General** section:
   - Check **This project is parameterized**
   - Add parameters (optional, as they're defined in Jenkinsfile)

2. **Build Triggers** section:
   - Configure as needed (e.g., GitHub webhook)

3. **Pipeline** section:
   - **Definition**: Pipeline script from SCM
   - **SCM**: Git
   - **Repository URL**: Your repository URL
   - **Credentials**: Add GitHub credentials if private repo
   - **Branch Specifier**: `*/main`
   - **Script Path**: `jenkins/Jenkinsfile`

4. Click **Save**

## Configuring Build Agent

### Option 1: Use Master Node

Update Jenkinsfile to use `any` instead of `terraform` label:

```groovy
agent {
    label 'any'
}
```

### Option 2: Configure Terraform Agent

1. **Set up a Jenkins agent** with:
   - Terraform installed
   - AWS CLI installed
   - Git installed

2. **Label the agent** as `terraform`:
   - Go to **Manage Jenkins** → **Manage Nodes and Clouds**
   - Click on the node
   - Click **Configure**
   - Add label: `terraform`
   - Save

## Common Issues and Solutions

### Issue 1: "Invalid option type 'ansiColor'"

**Error**:
```
Invalid option type "ansiColor". Valid option types: [buildDiscarder, ...]
```

**Solution**:
The AnsiColor plugin is not installed. Either:

**A) Install the plugin:**
```bash
java -jar jenkins-cli.jar -s http://jenkins-url/ install-plugin ansicolor
```

**B) Remove from Jenkinsfile (already done):**
The current Jenkinsfile has this removed.

### Issue 2: "No valid credentials"

**Error**:
```
Credentials 'aws-credentials' not found
```

**Solution**:
1. Verify credentials exist in Jenkins
2. Check the credentials ID matches exactly: `aws-credentials`
3. Ensure credentials are in the global domain

### Issue 3: "Agent label 'terraform' is offline"

**Error**:
```
There are no nodes with the label 'terraform'
```

**Solution**:

**Option A:** Use master node
```groovy
agent {
    label 'master'
}
```

**Option B:** Create and label an agent
1. Go to **Manage Jenkins** → **Manage Nodes and Clouds**
2. Create new node or configure existing
3. Add label `terraform`

### Issue 4: Terraform not found

**Error**:
```
terraform: command not found
```

**Solution**:
The Jenkinsfile includes automatic Terraform installation. Ensure:
1. Agent has internet access
2. Agent has `wget` and `unzip` installed
3. Agent has `sudo` permissions (or pre-install Terraform)

### Issue 5: AWS credentials not working

**Error**:
```
Unable to locate credentials
```

**Solution**:
1. Verify IAM user has correct permissions
2. Check access key is active
3. Test credentials manually:
```bash
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
aws sts get-caller-identity
```

## Testing the Pipeline

### Step 1: Run with Plan Action

1. Click **Build with Parameters**
2. Select:
   - **ACTION**: `plan`
   - **ENVIRONMENT**: `dev`
   - **AUTO_APPROVE**: `false`
3. Click **Build**

### Step 2: Review Console Output

1. Click on the build number
2. Click **Console Output**
3. Verify:
   - Checkout successful
   - Terraform initialization successful
   - Plan created without errors

### Step 3: Run Apply (if plan looks good)

1. Click **Build with Parameters**
2. Select:
   - **ACTION**: `apply`
   - **ENVIRONMENT**: `dev`
   - **AUTO_APPROVE**: `false`
3. Click **Build**
4. Approve when prompted

## Best Practices

### 1. Use Approval Gates

 Always set `AUTO_APPROVE` to `false` for production:

```groovy
parameters {
    booleanParam(
        name: 'AUTO_APPROVE',
        defaultValue: false
    )
}
```

### 2. Limit Access

Restrict who can approve deployments:

```groovy
input(
    message: "Deploy to production?",
    submitter: 'admin,devops,tech-lead'
)
```

### 3. Use Separate Credentials Per Environment

Create different AWS credentials:
- `aws-credentials-dev`
- `aws-credentials-staging`
- `aws-credentials-prod`

Update Jenkinsfile:
```groovy
withCredentials([[
    $class: 'AmazonWebServicesCredentialsBinding',
    credentialsId: "aws-credentials-${params.ENVIRONMENT}"
]]) {
    // ...
}
```

### 4. Enable Build Notifications

Uncomment email notifications in `post` section:

```groovy
post {
    success {
        emailext(
            subject: "SUCCESS: RDS Deployment - ${params.ENVIRONMENT}",
            body: "Deployment completed successfully",
            to: 'devops-team@company.com'
        )
    }
    failure {
        emailext(
            subject: "FAILED: RDS Deployment - ${params.ENVIRONMENT}",
            body: "Deployment failed. Check console output.",
            to: 'devops-team@company.com'
        )
    }
}
```

### 5. Archive Terraform Plans

Plans are automatically archived. Download via:
1. Build page → **Build Artifacts**
2. Download `plan.txt` or `outputs.json`

## Monitoring Pipeline

### View Stage Progress

1. Click on build number
2. Click **Pipeline Steps** or use Blue Ocean
3. View stage-by-stage progress

### Check Logs

```bash
# Via Jenkins CLI
java -jar jenkins-cli.jar -s http://jenkins-url/ console <job-name> <build-number>
```

## Troubleshooting Commands

### Check Jenkins Plugins

```bash
# List installed plugins
java -jar jenkins-cli.jar -s http://jenkins-url/ list-plugins

# Check specific plugin
java -jar jenkins-cli.jar -s http://jenkins-url/ list-plugins | grep aws
```

### Test AWS Credentials

Add a test stage to Jenkinsfile:

```groovy
stage('Test AWS') {
    steps {
        withCredentials([[
            $class: 'AmazonWebServicesCredentialsBinding',
            credentialsId: 'aws-credentials'
        ]]) {
            sh 'aws sts get-caller-identity'
        }
    }
}
```

## Advanced Configuration

### Enable Docker Agent

Use Docker for clean, reproducible builds:

```groovy
agent {
    docker {
        image 'hashicorp/terraform:1.5.7'
        label 'docker'
    }
}
```

### Parallel Execution

Run multiple environments in parallel:

```groovy
stage('Deploy Multiple Envs') {
    parallel {
        stage('Dev') {
            steps {
                // Deploy to dev
            }
        }
        stage('Staging') {
            steps {
                // Deploy to staging
            }
        }
    }
}
```

## Support

- Jenkins Documentation: https://www.jenkins.io/doc/
- Pipeline Syntax: https://www.jenkins.io/doc/book/pipeline/syntax/
- AWS Steps Plugin: https://plugins.jenkins.io/aws-credentials/

## Quick Reference

### Required Credentials

| ID | Type | Description |
|----|------|-------------|
| `aws-credentials` | AWS Credentials | For Terraform AWS operations |

### Required Plugins

- workflow-aggregator (Pipeline)
- git
- aws-credentials
- credentials-binding
- timestamper

### Pipeline Parameters

| Parameter | Type | Values |
|-----------|------|--------|
| ACTION | Choice | plan, apply, destroy |
| ENVIRONMENT | Choice | dev, staging, prod |
| AUTO_APPROVE | Boolean | true, false |
