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
                        
                        if [ "${ACTION}" == "CREATE" ]; then
                            if [ "$STACK_EXISTS" == "true" ]; then
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
                            
                        elif [ "${ACTION}" == "UPDATE" ]; then
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
                            
                        elif [ "${ACTION}" == "DELETE" ]; then
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
                echo "Pipeline execution completed."
                cleanWs()
            }
        }
        success {
            script {
                echo "Pipeline succeeded. Stack deployment completed successfully."
            }
        }
        failure {
            script {
                echo "Pipeline failed. Check the logs above for error details."
            }
        }
    }
}
