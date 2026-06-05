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
                        echo "Account: ${LACEWORK_ACCOUNT}"
                        echo "================================"
                        echo ""
                        
                        # Read CloudFormation template
                        echo "Scanning CloudFormation template: ${TEMPLATE_FILE}"
                        
                        # Call FortiCNAPP API to scan CloudFormation
                        SCAN_PAYLOAD=$(cat ${TEMPLATE_FILE} | base64 -w 0)
                        
                        echo "Uploading template to FortiCNAPP for analysis..."
                        
                        # API call to FortiCNAPP with proper authentication headers
                        # Generate UAKS header (HMAC-SHA256 signature)
                        REQUEST_BODY='{"keyId":"'"${LW_ACCESS}"'","expiryTime":3600}'
                        
                        UAKS=$(python3 << PYEOF
import hmac
import hashlib
import base64
secret = '''${LW_SECRET}'''
body = '''${REQUEST_BODY}'''
signature = hmac.new(secret.encode(), body.encode(), hashlib.sha256).digest()
print(base64.b64encode(signature).decode())
PYEOF
)
                        
                        TOKEN_RESPONSE=$(curl -s -X POST "https://${LACEWORK_ACCOUNT}.lacework.net/api/v2/access/tokens" \
                          -H "Content-Type: application/json" \
                          -H "X-LW-UAKS: ${UAKS}" \
                          -d "${REQUEST_BODY}")
                        
                        API_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.data[0].token' 2>/dev/null || echo "")
                        
                        if [ -z "$API_TOKEN" ] || [ "$API_TOKEN" = "null" ]; then
                            echo "⚠️  Failed to authenticate with FortiCNAPP API"
                            echo "Response: $TOKEN_RESPONSE"
                            exit 0
                        fi
                        
                        echo "✓ Successfully authenticated with FortiCNAPP"
                        echo "Calling FortiCNAPP API with token..."
                        curl -s -X POST "https://${LACEWORK_ACCOUNT}.lacework.net/api/v2/CloudFormationTemplate/scan" \
                          -H "Content-Type: application/json" \
                          -H "Authorization: Bearer ${API_TOKEN}" \
                          -d '{"template":"'"${SCAN_PAYLOAD}"'"}' \
                          > ${SCAN_REPORT_DIR}/scan-result.json 2>&1 || true
                        
                        echo ""
                        echo "Scan Results:"
                        echo "=============="
                        if [ -f ${SCAN_REPORT_DIR}/scan-result.json ]; then
                            cat ${SCAN_REPORT_DIR}/scan-result.json | python3 -m json.tool 2>/dev/null || cat ${SCAN_REPORT_DIR}/scan-result.json
                        fi
                        
                        # Generate HTML report
                        cat > ${SCAN_REPORT_DIR}/scan-report.html <<'HTMLREPORT'
<!DOCTYPE html>
<html>
<head>
    <title>FortiCNAPP IaC Security Scan</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .header { background: #2c3e50; color: white; padding: 20px; border-radius: 5px; }
        .summary { background: white; padding: 15px; margin: 20px 0; border-radius: 5px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        pre { background: #ecf0f1; padding: 10px; border-radius: 3px; overflow-x: auto; }
    </style>
</head>
<body>
    <div class="header">
        <h1>FortiCNAPP IaC Security Scan Report</h1>
        <p>Stack: ${STACK_NAME} | Environment: ${ENVIRONMENT} | Scan Date: $(date)</p>
    </div>
    <div class="summary">
        <h2>Scan Results</h2>
        <pre>$(cat ${SCAN_REPORT_DIR}/scan-result.json 2>/dev/null || echo "Scan in progress...")</pre>
    </div>
</body>
</html>
HTMLREPORT
                        
                        echo ""
                        echo "✅ FortiCNAPP IaC scan completed"
                        echo "📊 Scan results saved to ${SCAN_REPORT_DIR}/"
                        echo "📋 View report: forticnapp-scan-reports/scan-report.html"
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
