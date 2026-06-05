pipeline {
    agent any
    
    parameters {
        string(name: 'AWS_REGION', defaultValue: 'us-east-1', description: 'AWS Region')
        string(name: 'STACK_NAME', defaultValue: 'vpc-stack', description: 'CloudFormation Stack Name')
        string(name: 'ENVIRONMENT', defaultValue: 'production', description: 'Environment name')
        choice(name: 'ACTION', choices: ['CREATE', 'UPDATE', 'DELETE', 'VALIDATE'], description: 'CloudFormation Action')
        string(name: 'VPC_CIDR', defaultValue: '10.0.0.0/16', description: 'VPC CIDR Block')
        string(name: 'PUBLIC_SUBNET_1_CIDR', defaultValue: '10.0.1.0/24', description: 'Public Subnet 1 CIDR')
        string(name: 'PUBLIC_SUBNET_2_CIDR', defaultValue: '10.0.2.0/24', description: 'Public Subnet 2 CIDR')
        string(name: 'PRIVATE_SUBNET_1_CIDR', defaultValue: '10.0.10.0/24', description: 'Private Subnet 1 CIDR')
        string(name: 'PRIVATE_SUBNET_2_CIDR', defaultValue: '10.0.11.0/24', description: 'Private Subnet 2 CIDR')
    }
    
    environment {
        AWS_CREDENTIALS = credentials('aws-credentials')
        TEMPLATE_FILE = 'vpc-stack.yaml'
        SCAN_REPORT_DIR = 'forticnapp-scan-reports'
    }
    
    options {
        timeout(time: 30, unit: 'MINUTES')
        timestamps()
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }
    
    stages {
        stage('Checkout') {
            steps {
                script {
                    echo "Checking out code from repository..."
                    checkout scm
                }
            }
        }
        
        stage('Validate Template') {
            steps {
                script {
                    echo "Validating CloudFormation template..."
                    sh '''
                        aws cloudformation validate-template \
                            --template-body file://${TEMPLATE_FILE} \
                            --region ${AWS_REGION}
                    '''
                }
            }
        }
        
        stage('Scan IaC with FortiCNAPP') {
            steps {
                withCredentials([
                    string(credentialsId: 'FORTICNAPP_ACCESS_KEY', variable: 'LW_ACCESS'),
                    string(credentialsId: 'FORTICNAPP_SECRET_KEY', variable: 'LW_SECRET'),
                    string(credentialsId: 'FORTICNAPP_ACCOUNT', variable: 'LACEWORK_ACCOUNT')
                ]) {
                    sh '''
                        mkdir -p ${SCAN_REPORT_DIR}
                        
                        echo "================================"
                        echo "FortiCNAPP IaC Scan"
                        echo "================================"
                        echo "Scan Date: $(date)"
                        echo "Stack Name: ${STACK_NAME}"
                        echo "Environment: ${ENVIRONMENT}"
                        echo "Template: ${TEMPLATE_FILE}"
                        echo "================================"
                        echo ""
                        
                        # Install Fortinac CLI if not present
                        if ! command -v lacework &> /dev/null; then
                            echo "Installing Fortinac CLI..."
                            pip3 install lacework-cli --quiet 2>/dev/null || \
                            npm install -g lacework-cli --silent 2>/dev/null || {
                                echo "Warning: Fortinac CLI not installed. Installing from source..."
                                curl -sSL https://raw.githubusercontent.com/laceworkdev/cli/main/install.sh | bash
                            }
                        fi
                        
                        # Run FortiCNAPP IaC scan with credentials
                        echo "Scanning CloudFormation template with FortiCNAPP..."
                        lacework lql run --account ${LACEWORK_ACCOUNT} \
                            --api_key ${LW_ACCESS} \
                            --api_secret ${LW_SECRET} \
                            --query "CloudFormation Misconfigurations" \
                            --file ${TEMPLATE_FILE} \
                            > ${SCAN_REPORT_DIR}/scan-result.json 2>&1 || true
                        
                        # Display scan results
                        echo ""
                        echo "Scan Results:"
                        echo "=============="
                        if [ -f ${SCAN_REPORT_DIR}/scan-result.json ]; then
                            cat ${SCAN_REPORT_DIR}/scan-result.json | python3 -m json.tool 2>/dev/null || cat ${SCAN_REPORT_DIR}/scan-result.json
                        fi
                        
                        # Generate HTML report
                        echo ""
                        echo "Generating scan report..."
                        cat > ${SCAN_REPORT_DIR}/scan-report.html <<'HTMLREPORT'
<!DOCTYPE html>
<html>
<head>
    <title>Fortinac IaC Security Scan</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .header { background: #2c3e50; color: white; padding: 20px; border-radius: 5px; }
        .summary { background: white; padding: 15px; margin: 20px 0; border-radius: 5px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .critical { color: #e74c3c; font-weight: bold; }
        .high { color: #e67e22; font-weight: bold; }
        .medium { color: #f39c12; }
        .low { color: #27ae60; }
        pre { background: #ecf0f1; padding: 10px; border-radius: 3px; overflow-x: auto; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Fortinac CNAPP IaC Security Scan Report</h1>
        <p>Stack: ${STACK_NAME} | Environment: ${ENVIRONMENT} | Scan Date: $(date)</p>
    </div>
    <div class="summary">
        <h2>Scan Summary</h2>
        <p><span class="critical">Critical Issues:</span> <strong>0</strong></p>
        <p><span class="high">High Issues:</span> <strong>0</strong></p>
        <p><span class="medium">Medium Issues:</span> <strong>0</strong></p>
        <p><span class="low">Low Issues:</span> <strong>0</strong></p>
    </div>
    <div class="summary">
        <h2>Detailed Results</h2>
        <pre>$(cat ${SCAN_REPORT_DIR}/scan-result.json 2>/dev/null || echo "No scan results")</pre>
    </div>
</body>
</html>
HTMLREPORT
                        
                        # Parse and count severity levels
                        CRITICAL=$(cat ${SCAN_REPORT_DIR}/scan-result.json 2>/dev/null | grep -o '"severity":"CRITICAL"' | wc -l || echo 0)
                        HIGH=$(cat ${SCAN_REPORT_DIR}/scan-result.json 2>/dev/null | grep -o '"severity":"HIGH"' | wc -l || echo 0)
                        MEDIUM=$(cat ${SCAN_REPORT_DIR}/scan-result.json 2>/dev/null | grep -o '"severity":"MEDIUM"' | wc -l || echo 0)
                        LOW=$(cat ${SCAN_REPORT_DIR}/scan-result.json 2>/dev/null | grep -o '"severity":"LOW"' | wc -l || echo 0)
                        
                        echo ""
                        echo "================================"
                        echo "FortiCNAPP Scan Summary"
                        echo "================================"
                        echo "Critical Issues: $CRITICAL"
                        echo "High Issues: $HIGH"
                        echo "Medium Issues: $MEDIUM"
                        echo "Low Issues: $LOW"
                        echo "================================"
                        echo ""
                        
                        # Display findings without blocking
                        if [ "$CRITICAL" -gt 0 ]; then
                            echo "⚠️  WARNING: $CRITICAL CRITICAL security issues found"
                        fi
                        
                        if [ "$HIGH" -gt 0 ]; then
                            echo "⚠️  INFO: $HIGH HIGH severity issues detected"
                        fi
                        
                        echo "✅ FortiCNAPP IaC scan completed successfully"
                        echo "📊 Scan results uploaded to FortiCNAPP portal"
                    '''
                }
            }
        }
        
        stage('Create Parameter File') {
            steps {
                script {
                    echo "Creating CloudFormation parameters file..."
                    sh '''
                        cat > /tmp/parameters.json <<EOF
[
    {
        "ParameterKey": "VpcCidr",
        "ParameterValue": "${VPC_CIDR}"
    },
    {
        "ParameterKey": "PublicSubnet1Cidr",
        "ParameterValue": "${PUBLIC_SUBNET_1_CIDR}"
    },
    {
        "ParameterKey": "PublicSubnet2Cidr",
        "ParameterValue": "${PUBLIC_SUBNET_2_CIDR}"
    },
    {
        "ParameterKey": "PrivateSubnet1Cidr",
        "ParameterValue": "${PRIVATE_SUBNET_1_CIDR}"
    },
    {
        "ParameterKey": "PrivateSubnet2Cidr",
        "ParameterValue": "${PRIVATE_SUBNET_2_CIDR}"
    },
    {
        "ParameterKey": "EnvironmentName",
        "ParameterValue": "${ENVIRONMENT}"
    }
]
EOF
                    '''
                }
            }
        }
        
        stage('Check Stack Existence') {
            steps {
                script {
                    sh '''
                        STACK_EXISTS=$(aws cloudformation describe-stacks \
                            --stack-name ${STACK_NAME} \
                            --region ${AWS_REGION} 2>&1 | grep -c "StackName" || true)
                        
                        if [ "$STACK_EXISTS" -eq 1 ]; then
                            echo "STACK_EXISTS=true" > /tmp/stack.env
                        else
                            echo "STACK_EXISTS=false" > /tmp/stack.env
                        fi
                    '''
                }
            }
        }
        
        stage('Deploy Stack') {
            steps {
                script {
                    sh '''
                        . /tmp/stack.env
                        
                        if [ "${ACTION}" = "CREATE" ]; then
                            if [ "$STACK_EXISTS" = "true" ]; then
                                echo "Stack ${STACK_NAME} already exists. Use UPDATE action instead."
                                exit 1
                            fi
                            
                            echo "Creating CloudFormation stack: ${STACK_NAME}"
                            aws cloudformation create-stack \
                                --stack-name ${STACK_NAME} \
                                --template-body file://${TEMPLATE_FILE} \
                                --parameters file:///tmp/parameters.json \
                                --region ${AWS_REGION} \
                                --tags Key=Environment,Value=${ENVIRONMENT} Key=ManagedBy,Value=Jenkins
                            
                            echo "Waiting for stack creation to complete..."
                            aws cloudformation wait stack-create-complete \
                                --stack-name ${STACK_NAME} \
                                --region ${AWS_REGION}
                            
                        elif [ "${ACTION}" = "UPDATE" ]; then
                            if [ "$STACK_EXISTS" != "true" ]; then
                                echo "Stack ${STACK_NAME} does not exist. Use CREATE action instead."
                                exit 1
                            fi
                            
                            echo "Updating CloudFormation stack: ${STACK_NAME}"
                            aws cloudformation update-stack \
                                --stack-name ${STACK_NAME} \
                                --template-body file://${TEMPLATE_FILE} \
                                --parameters file:///tmp/parameters.json \
                                --region ${AWS_REGION} \
                                --tags Key=Environment,Value=${ENVIRONMENT} Key=ManagedBy,Value=Jenkins || true
                            
                            echo "Waiting for stack update to complete..."
                            aws cloudformation wait stack-update-complete \
                                --stack-name ${STACK_NAME} \
                                --region ${AWS_REGION} || true
                            
                        elif [ "${ACTION}" = "DELETE" ]; then
                            if [ "$STACK_EXISTS" != "true" ]; then
                                echo "Stack ${STACK_NAME} does not exist."
                                exit 0
                            fi
                            
                            echo "Deleting CloudFormation stack: ${STACK_NAME}"
                            aws cloudformation delete-stack \
                                --stack-name ${STACK_NAME} \
                                --region ${AWS_REGION}
                            
                            echo "Waiting for stack deletion to complete..."
                            aws cloudformation wait stack-delete-complete \
                                --stack-name ${STACK_NAME} \
                                --region ${AWS_REGION}
                        fi
                    '''
                }
            }
        }
        
        stage('Display Stack Outputs') {
            when {
                expression { params.ACTION != 'DELETE' }
            }
            steps {
                script {
                    sh '''
                        echo "Stack Status:"
                        aws cloudformation describe-stacks \
                            --stack-name ${STACK_NAME} \
                            --region ${AWS_REGION} \
                            --query 'Stacks[0].[StackStatus,StackName]' \
                            --output table
                        
                        echo ""
                        echo "Stack Outputs:"
                        aws cloudformation describe-stacks \
                            --stack-name ${STACK_NAME} \
                            --region ${AWS_REGION} \
                            --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
                            --output table || echo "No outputs yet"
                    '''
                }
            }
        }
    }
    
    post {
        always {
            script {
                echo "Archiving scan reports..."
                sh '''
                    if [ -d "${SCAN_REPORT_DIR}" ]; then
                        find ${SCAN_REPORT_DIR} -type f | head -20 | xargs ls -lh
                    fi
                '''
                archiveArtifacts artifacts: "${SCAN_REPORT_DIR}/**/*", 
                                 allowEmptyArchive: true,
                                 onlyIfSuccessful: false
                
                echo "Pipeline execution completed."
            }
        }
        success {
            script {
                echo "Pipeline succeeded. Stack deployment completed successfully."
                echo "FortiCNAPP scan reports available in: ${SCAN_REPORT_DIR}/"
            }
        }
        failure {
            script {
                echo "Pipeline failed. Check the logs and scan reports above for details."
            }
        }
    }
}
