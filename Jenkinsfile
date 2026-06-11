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
                        set -e
                        REPORT_DIR="${SCAN_REPORT_DIR}"
                        mkdir -p "$REPORT_DIR"

                        echo "================================"
                        echo "Starting FortiCNAPP IaC Scan"
                        echo "================================"

                        # Validate credentials
                        if [ -z "$LW_ACCESS" ] || [ -z "$LW_SECRET" ] || [ -z "$LACEWORK_ACCOUNT" ]; then
                            echo "ERROR: Missing FortiCNAPP credentials (LW_ACCESS, LW_SECRET, LACEWORK_ACCOUNT)"
                            exit 1
                        fi

                        # Install Lacework CLI if not present
                        if ! command -v lacework >/dev/null 2>&1; then
                            echo "Installing Lacework CLI..."
                            curl -L https://github.com/lacework/go-lacework/releases/latest/download/lacework-linux-amd64 \
                                -o /usr/local/bin/lacework
                            chmod +x /usr/local/bin/lacework
                        fi

                        # Run IaC scan on CloudFormation template
                        echo "Scanning: ${TEMPLATE_FILE}"
                        REPORT_JSON="$REPORT_DIR/scan-result.json"

                        lacework iac scan \
                            --iac-type cloudformation \
                            --file "${TEMPLATE_FILE}" \
                            --output json \
                            --save-results \
                            -a "${LACEWORK_ACCOUNT}" \
                            -k "${LW_ACCESS}" \
                            -s "${LW_SECRET}" > "$REPORT_JSON" 2>&1 || true

                        # Print raw scan output for debugging
                        echo "--- Raw scan output ---"
                        cat "$REPORT_JSON" || echo "(empty)"
                        echo "--- End scan output ---"

                        # Parse and display results
                        ISSUE_COUNT=$(jq '[.. | objects | select(has("severity"))] | length' "$REPORT_JSON" 2>/dev/null || echo "0")
                        if [ "$ISSUE_COUNT" -gt 0 ]; then
                            echo "WARNING: Found $ISSUE_COUNT issue(s) in ${TEMPLATE_FILE}"
                        else
                            echo "No issues found in ${TEMPLATE_FILE}"
                        fi

                        # Generate HTML report
                        SCAN_DATE=$(date)
                        REPORT_HTML="$REPORT_DIR/scan-report.html"
                        cat > "$REPORT_HTML" <<HTML
<!DOCTYPE html>
<html>
<head>
    <title>FortiCNAPP IaC Security Scan Report</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); min-height: 100vh; padding: 20px; }
        .container { max-width: 1200px; margin: 0 auto; background: white; border-radius: 10px; box-shadow: 0 10px 40px rgba(0,0,0,0.2); overflow: hidden; }
        .header { background: linear-gradient(135deg, #2c3e50 0%, #34495e 100%); color: white; padding: 40px 20px; text-align: center; }
        .header h1 { font-size: 28px; margin-bottom: 10px; }
        .content { padding: 30px; }
        .stat-card { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 8px; text-align: center; display: inline-block; min-width: 200px; margin: 10px; }
        .stat-card h4 { font-size: 14px; opacity: 0.9; margin-bottom: 10px; }
        .stat-card .number { font-size: 32px; font-weight: bold; }
        pre { background: #2c3e50; color: #ecf0f1; padding: 15px; border-radius: 4px; overflow-x: auto; font-size: 12px; max-height: 400px; overflow-y: auto; margin-top: 20px; }
        .footer { background: #f8f9fa; padding: 20px; text-align: center; color: #666; font-size: 12px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>FortiCNAPP IaC Security Scan Report</h1>
            <p>Scan Date: <strong>${SCAN_DATE}</strong></p>
        </div>
        <div class="content">
            <div class="stat-card"><h4>Files Scanned</h4><div class="number">1</div></div>
            <div class="stat-card"><h4>Issues Found</h4><div class="number">${ISSUE_COUNT}</div></div>
            <div class="stat-card"><h4>Account</h4><div class="number">${LACEWORK_ACCOUNT}</div></div>
            <h2 style="margin-top:30px;">Scan Results: ${TEMPLATE_FILE}</h2>
            <pre>$(jq . "$REPORT_JSON" 2>/dev/null || cat "$REPORT_JSON")</pre>
        </div>
        <div class="footer">Generated by FortiCNAPP IaC Scanner | ${SCAN_DATE}</div>
    </div>
</body>
</html>
HTML

                        echo "================================"
                        echo "Scan complete. Reports saved to: $REPORT_DIR"
                        echo "================================"
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
                            UPDATE_OUTPUT=$(aws cloudformation update-stack \
                                --stack-name ${STACK_NAME} \
                                --template-body file://${TEMPLATE_FILE} \
                                --parameters file:///tmp/parameters.json \
                                --region ${AWS_REGION} \
                                --tags Key=Environment,Value=${ENVIRONMENT} Key=ManagedBy,Value=Jenkins 2>&1)
                            
                            UPDATE_STATUS=$?
                            echo "$UPDATE_OUTPUT"
                            
                            # Check if update was initiated
                            if echo "$UPDATE_OUTPUT" | grep -q "No updates are to be performed"; then
                                echo "ℹ️  No changes detected. Stack is already up to date."
                            elif [ $UPDATE_STATUS -eq 0 ]; then
                                echo "Waiting for stack update to complete..."
                                aws cloudformation wait stack-update-complete \
                                    --stack-name ${STACK_NAME} \
                                    --region ${AWS_REGION}
                            else
                                echo "⚠️  Update encountered an error but continuing..."
                            fi
                            
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
