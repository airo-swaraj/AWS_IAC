# AWS VPC CloudFormation Deployment with Jenkins

This repository contains Infrastructure as Code (IaC) files for deploying a simple VPC on AWS using CloudFormation and Jenkins CI/CD pipeline.

## Project Structure

```
AWS_IAC/
├── vpc-stack.yaml           # CloudFormation template for VPC
├── Jenkinsfile              # Jenkins pipeline configuration
├── parameters.json          # CloudFormation parameters file
├── setup-jenkins-creds.sh   # Script to setup AWS credentials in Jenkins
└── README.md                # This file
```

## Architecture Overview

The CloudFormation template deploys:
- **VPC** with configurable CIDR block (default: 10.0.0.0/16)
- **Public Subnets** (2x) in different availability zones
- **Private Subnets** (2x) in different availability zones
- **Internet Gateway** for public subnet internet access
- **Route Tables** for public and private routing
- **Security Groups** for public and private resources

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **Jenkins Server** running on a VM (Ubuntu/CentOS)
3. **AWS CLI** installed on Jenkins server
4. **IAM User/Role** with CloudFormation, EC2, and VPC permissions
5. **Git** installed on Jenkins server

## Setup Steps

### 1. Create IAM User for Jenkins (AWS Console)

```bash
# Permissions needed:
# - cloudformation:*
# - ec2:*
# - iam:PassRole
```

Create an IAM user and generate Access Key ID and Secret Access Key.

### 2. Install Jenkins on VM

#### On Ubuntu 20.04+:
```bash
# Update system
sudo apt-get update
sudo apt-get upgrade -y

# Install Java
sudo apt-get install -y openjdk-11-jdk

# Add Jenkins repository
wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io.key | sudo apt-key add -
sudo sh -c 'echo deb https://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'

# Install Jenkins
sudo apt-get update
sudo apt-get install -y jenkins

# Start Jenkins
sudo systemctl start jenkins
sudo systemctl enable jenkins

# Check status
sudo systemctl status jenkins
```

#### On CentOS/RHEL:
```bash
# Install Java
sudo yum install -y java-11-openjdk java-11-openjdk-devel

# Add Jenkins repository
sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key

# Install Jenkins
sudo yum install -y jenkins

# Start Jenkins
sudo systemctl start jenkins
sudo systemctl enable jenkins

# Check status
sudo systemctl status jenkins
```

### 3. Access Jenkins Web UI

Jenkins runs on port 8080. Access it at: `http://your-vm-ip:8080`

Get the initial admin password:
```bash
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

Complete the initial setup and install suggested plugins.

### 4. Install AWS CLI on Jenkins Server

```bash
# Install Python and pip
sudo apt-get install -y python3 python3-pip

# Install AWS CLI
pip3 install awscli

# Verify installation
aws --version
```

### 5. Configure AWS Credentials in Jenkins

#### Option A: Using Jenkins UI (Recommended for automated setup)
1. Go to **Manage Jenkins** → **Manage Credentials**
2. Click **Global** → **Add Credentials**
3. Select **AWS Credentials**
4. Enter:
   - **ID**: `aws-credentials`
   - **Access Key ID**: Your AWS Access Key
   - **Secret Access Key**: Your AWS Secret Key
   - **Region**: `us-east-1` (or your preferred region)
5. Click **Create**

#### Option B: Using the provided script
```bash
# Make the script executable
chmod +x setup-jenkins-creds.sh

# Run the script (enter credentials when prompted)
./setup-jenkins-creds.sh
```

### 6. Create a New Pipeline Job in Jenkins

1. Go to Jenkins Dashboard
2. Click **New Item**
3. Enter job name: `vpc-deployment`
4. Select **Pipeline**
5. Click **OK**
6. Under **Pipeline** section:
   - Select **Pipeline script from SCM**
   - Choose **Git**
   - Repository URL: Your Git repo URL (e.g., GitHub repo)
   - Credentials: Select your Git credentials
   - Branch: `*/main` (or your branch)
   - Script Path: `Jenkinsfile`
7. Click **Save**

### 7. Verify CloudFormation Template

Before running the pipeline, validate the template locally:

```bash
aws cloudformation validate-template \
    --template-body file://vpc-stack.yaml \
    --region us-east-1
```

## Running the Pipeline

### Option 1: Using Jenkins Web UI

1. Go to your job: `vpc-deployment`
2. Click **Build with Parameters**
3. Set parameters:
   - **ACTION**: SELECT `CREATE` for new stack, `UPDATE` for existing, `DELETE` to remove
   - **AWS_REGION**: `us-east-1` (or your region)
   - **STACK_NAME**: `vpc-stack` (or custom name)
   - **ENVIRONMENT**: `production` (or `dev`, `staging`)
   - **VPC_CIDR**: `10.0.0.0/16` (or custom CIDR)
   - Other subnet CIDRs as needed
4. Click **Build**

### Option 2: Using AWS CLI Manually

```bash
# Validate template
aws cloudformation validate-template \
    --template-body file://vpc-stack.yaml \
    --region us-east-1

# Create stack
aws cloudformation create-stack \
    --stack-name vpc-stack \
    --template-body file://vpc-stack.yaml \
    --parameters file://parameters.json \
    --region us-east-1

# Check stack status
aws cloudformation describe-stacks \
    --stack-name vpc-stack \
    --region us-east-1

# View stack outputs
aws cloudformation describe-stacks \
    --stack-name vpc-stack \
    --region us-east-1 \
    --query 'Stacks[0].Outputs'
```

## Pipeline Stages

1. **Checkout** - Clones the repository
2. **Validate Template** - Validates CloudFormation syntax
3. **Create Parameter File** - Generates parameter file from Jenkins parameters
4. **Check Stack Existence** - Verifies if stack already exists
5. **Deploy Stack** - Creates, updates, or deletes the stack based on ACTION
6. **Display Stack Outputs** - Shows VPC, subnet, and security group IDs

## CloudFormation Outputs

After successful deployment, the stack outputs include:

- **VpcId** - ID of the created VPC
- **PublicSubnet1Id** - ID of public subnet 1
- **PublicSubnet2Id** - ID of public subnet 2
- **PrivateSubnet1Id** - ID of private subnet 1
- **PrivateSubnet2Id** - ID of private subnet 2
- **PublicSecurityGroupId** - ID of public security group
- **PrivateSecurityGroupId** - ID of private security group

## Customization

### Modify VPC Parameters

Edit `parameters.json` or pass parameters when running the pipeline:

```json
{
  "VpcCidr": "172.16.0.0/16",
  "PublicSubnet1Cidr": "172.16.1.0/24",
  "PublicSubnet2Cidr": "172.16.2.0/24",
  "PrivateSubnet1Cidr": "172.16.10.0/24",
  "PrivateSubnet2Cidr": "172.16.11.0/24"
}
```

### Extend the Template

To add more resources (RDS, ALB, etc.), modify `vpc-stack.yaml`:

1. Add new resources in the `Resources` section
2. Add outputs in the `Outputs` section
3. Update parameters if needed
4. Validate and re-deploy

## Troubleshooting

### Stack Creation Fails

```bash
# Check stack events for errors
aws cloudformation describe-stack-events \
    --stack-name vpc-stack \
    --region us-east-1

# Check stack status
aws cloudformation describe-stacks \
    --stack-name vpc-stack \
    --region us-east-1 \
    --query 'Stacks[0].StackStatus'
```

### Jenkins Can't Access AWS

1. Verify AWS credentials in Jenkins credentials store
2. Check IAM user has CloudFormation and EC2 permissions
3. Verify AWS CLI is installed: `aws --version`
4. Test AWS CLI manually on Jenkins server: `aws s3 ls`

### Jenkins Freestyle Job vs Pipeline

This setup uses **Declarative Pipeline** (recommended). If you prefer:
- Easier UI configuration: Use Freestyle Job with CloudFormation plugin
- More control: Use Scripted Pipeline

## Security Best Practices

1. **Use IAM Roles** instead of access keys when possible
2. **Restrict IAM Permissions** to only required services
3. **Enable MFA** on AWS console and Jenkins
4. **Use Secrets Management** (AWS Secrets Manager, HashiCorp Vault)
5. **Enable VPC Flow Logs** for network monitoring
6. **Encrypt Stack Outputs** in Jenkins credentials

## Cleanup

To delete the VPC stack:

```bash
# Option 1: Via Jenkins pipeline
# Set ACTION to DELETE and run build

# Option 2: Via AWS CLI
aws cloudformation delete-stack \
    --stack-name vpc-stack \
    --region us-east-1

# Verify deletion
aws cloudformation wait stack-delete-complete \
    --stack-name vpc-stack \
    --region us-east-1
```

## References

- [AWS CloudFormation Documentation](https://docs.aws.amazon.com/cloudformation/)
- [Jenkins Pipeline Documentation](https://www.jenkins.io/doc/book/pipeline/)
- [AWS CLI Reference](https://docs.aws.amazon.com/cli/latest/)
- [VPC and Subnets](https://docs.aws.amazon.com/vpc/latest/userguide/)

## Support

For issues or improvements, please check:
1. AWS CloudFormation events and error messages
2. Jenkins build logs
3. AWS IAM permissions
4. Network connectivity between Jenkins and AWS API

---

**Created**: 2026-06-03  
**Template Version**: 1.0  
**Last Updated**: 2026-06-03
