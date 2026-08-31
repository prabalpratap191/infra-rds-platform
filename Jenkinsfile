// Jenkins Pipeline for RDS Infrastructure Deployment
// This pipeline handles Terraform deployment with proper gating and verification

pipeline {
   agent any
    
    parameters {
        choice(
            name: 'ACTION',
            choices: ['plan', 'apply', 'destroy'],
            description: 'Terraform action to perform'
        )
        choice(
            name: 'ENVIRONMENT',
            choices: ['dev', 'staging', 'prod'],
            description: 'Target environment'
        )
        booleanParam(
            name: 'AUTO_APPROVE',
            defaultValue: false,
            description: 'Auto-approve Terraform changes (use with caution!)'
        )
    }
    
    environment {
        AWS_REGION = 'us-east-1'
        TF_VERSION = '1.5.7'
        TF_IN_AUTOMATION = 'true'
        TF_INPUT = 'false'
        TF_CLI_ARGS = '-no-color'
        WORKSPACE_DIR = "${WORKSPACE}/terraform/environments/${params.ENVIRONMENT}"
    }
    
    options {
        buildDiscarder(logRotator(numToKeepStr: '30'))
        timeout(time: 1, unit: 'HOURS')
        timestamps()
    }
    
    stages {
        stage('Checkout') {
            steps {
                script {
                    echo "==========================================="
                    echo "RDS Platform Infrastructure Deployment"
                    echo "Environment: ${params.ENVIRONMENT}"
                    echo "Action: ${params.ACTION}"
                    echo "==========================================="
                }
                
                checkout scm
                
                sh '''
                    echo "Repository checked out successfully"
                    echo "Current directory: $(pwd)"
                    ls -la
                '''
            }
        }
        
        stage('Setup') {
            steps {
                script {
                    echo "Setting up Terraform environment..."
                }
                  withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'jenkins-user',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                sh '''
                    # Install Terraform if not present
                    if ! command -v terraform &> /dev/null; then
                        echo "Installing Terraform ${TF_VERSION}..."
                        wget https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_amd64.zip
                        unzip terraform_${TF_VERSION}_linux_amd64.zip
                        sudo mv terraform /usr/local/bin/
                        rm terraform_${TF_VERSION}_linux_amd64.zip
                    fi
                    
                    terraform version
                    
                    # Verify AWS credentials
                    aws sts get-caller-identity
                    echo "AWS credentials verified"
                '''
                }
            }
        }
        
        stage('Terraform Init') {
            steps {
                dir('terraform') {
                    script {
                        echo "Initializing Terraform..."
                    }
                    
                 withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'jenkins-user',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                        sh '''
                          
                            # Verify modules are copied
                            echo "Verifying modules directory:"
                            ls -la modules/

                            # Initialize with backend config
                            
                            terraform init \
                            -backend-config="bucket=terraform-state-rds-platform-dev" \
                            -backend-config="key=rds-platform/dev/terraform.tfstate" \
                            -backend-config="region=us-east-1" \
                            -backend-config="encrypt=true" \
                            -backend-config="dynamodb_table=terraform-state-lock-rds-platform -upgrade"
  

                            
                            
                            echo "Terraform initialized successfully"
                        '''
                    }
                }
            }
        }
        
        stage('Terraform Validate') {
            steps {
                dir("${WORKSPACE_DIR}") {
                    script {
                        echo "Validating Terraform configuration..."
                    }
                    withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'jenkins-user',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    sh '''
                        terraform validate
                        echo "✓ Terraform configuration is valid"
                        
                        terraform fmt -check -recursive || {
                            echo "Warning: Some files are not formatted correctly"
                            echo "Run 'terraform fmt -recursive' to fix"
                        }
                    '''
                }
                }
            }
        }
        
        stage('Terraform Plan') {
            when {
                expression { params.ACTION == 'plan' || params.ACTION == 'apply' }
            }
            steps {
                dir("${WORKSPACE_DIR}") {
                    script {
                        echo "Creating Terraform execution plan..."
                    }
                    
                   withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'jenkins-user',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                        sh '''
                            terraform plan \
                                -var-file="terraform.tfvars" \
                                -out=tfplan \
                                -detailed-exitcode || EXIT_CODE=$?
                            
                            if [ $EXIT_CODE -eq 0 ]; then
                                echo "No changes detected"
                            elif [ $EXIT_CODE -eq 2 ]; then
                                echo "Changes detected, plan created successfully"
                            else
                                echo "Plan failed with exit code $EXIT_CODE"
                                exit $EXIT_CODE
                            fi
                            
                            # Show plan summary
                            terraform show -no-color tfplan > plan.txt
                            echo "Plan saved to plan.txt"
                        '''
                    }
                    
                    // Archive the plan
                    archiveArtifacts artifacts: 'plan.txt', fingerprint: true
                }
            }
        }
        
        stage('Approval Gate') {
            when {
                allOf {
                    expression { params.ACTION == 'apply' || params.ACTION == 'destroy' }
                    expression { params.AUTO_APPROVE == false }
                }
            }
            steps {
                script {
                    def action = params.ACTION.toUpperCase()
                    
                    echo "==========================================="
                    echo "APPROVAL REQUIRED"
                    echo "Action: ${action}"
                    echo "Environment: ${params.ENVIRONMENT}"
                    echo "==========================================="
                    
                    timeout(time: 30, unit: 'MINUTES') {
                        input(
                            message: "Do you want to ${action} the infrastructure in ${params.ENVIRONMENT}?",
                            ok: "Yes, proceed with ${action}",
                            submitter: 'admin,devops'
                        )
                    }
                }
            }
        }
        
        stage('Terraform Apply') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                dir("${WORKSPACE_DIR}") {
                    script {
                        echo "Applying Terraform changes..."
                    }
                    
                    withCredentials([[
                        $class: 'AmazonWebServicesCredentialsBinding',
                        credentialsId: 'aws-credentials'
                    ]]) {
                        sh '''
                            terraform apply -auto-approve tfplan
                            
                            echo "==========================================="
                            echo "Terraform apply completed successfully!"
                            echo "==========================================="
                        '''
                    }
                }
            }
        }
        
        stage('Terraform Destroy') {
            when {
                expression { params.ACTION == 'destroy' }
            }
            steps {
                dir("${WORKSPACE_DIR}") {
                    script {
                        echo "WARNING: Destroying infrastructure in ${params.ENVIRONMENT}..."
                    }
                    
                   withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'jenkins-user',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                        sh '''
                            terraform destroy \
                                -var-file="terraform.tfvars" \
                                -auto-approve
                            
                            echo "Infrastructure destroyed"
                        '''
                    }
                }
            }
        }
        
        stage('Output Publishing') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                dir("${WORKSPACE_DIR}") {
                    script {
                        echo "Publishing Terraform outputs..."
                    }
                    
                    withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'jenkins-user',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                        sh '''
                            terraform output -json > outputs.json
                            terraform output > outputs.txt
                            
                            echo "==========================================="
                            echo "DEPLOYMENT OUTPUTS"
                            echo "==========================================="
                            cat outputs.txt
                        '''
                    }
                    
                    // Archive outputs
                    archiveArtifacts artifacts: 'outputs.json,outputs.txt', fingerprint: true
                }
            }
        }
        
        stage('Verification') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                dir("${WORKSPACE}") {
                    script {
                        echo "Running deployment verification..."
                    }
                    
                    withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'jenkins-user',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                        sh '''
                            chmod +x scripts/verify-deployment.sh
                            ./scripts/verify-deployment.sh ${ENVIRONMENT}
                        '''
                    }
                }
            }
        }
    }
    
    post {
        success {
            script {
                echo "==========================================="
                echo "Pipeline completed successfully!"
                echo "Action: ${params.ACTION}"
                echo "Environment: ${params.ENVIRONMENT}"
                echo "==========================================="
            }
            
            // Send notification (configure as needed)
            // emailext body: 'Pipeline succeeded', subject: 'RDS Deployment Success'
        }
        
        failure {
            script {
                echo "==========================================="
                echo "Pipeline failed!"
                echo "Action: ${params.ACTION}"
                echo "Environment: ${params.ENVIRONMENT}"
                echo "==========================================="
            }
            
            // Send notification (configure as needed)
            // emailext body: 'Pipeline failed', subject: 'RDS Deployment Failure'
        }
        
        always {
            // Clean up workspace
            cleanWs(
                deleteDirs: true,
                patterns: [
                    [pattern: '**/*.tfplan', type: 'INCLUDE'],
                    [pattern: '**/.terraform', type: 'INCLUDE']
                ]
            )
        }
    }
}
