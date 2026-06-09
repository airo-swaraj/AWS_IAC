# Jenkins Setup Guide (Manual EC2 Creation)

## Step 1: Create EC2 Instance via AWS Console

1. Go to **EC2 Dashboard** → **Launch Instances**
2. **Choose AMI**: Select `Ubuntu 20.04 LTS` or `Ubuntu 22.04 LTS`
3. **Instance Type**: Select `t2.medium` or `t3.medium` (recommended minimum)
4. **Configure Instance Details**:
   - VPC: Choose your default VPC or custom VPC
   - Subnet: Any public subnet
   - Auto-assign Public IP: Enable
5. **Add Storage**: 
   - Root volume: 20-30 GB (gp2 or gp3)
6. **Add Tags**:
   - Name: `jenkins-server`
   - Environment: `production`
7. **Configure Security Group**:
   - Create new or select existing
   - **Inbound Rules**:
     - SSH (22) from your IP or 0.0.0.0/0
     - Custom TCP (8080) from 0.0.0.0/0 (Jenkins port)
   - **Outbound Rules**: Allow all
8. **Review & Launch**: Launch the instance

## Step 2: Connect to EC2 Instance

```bash
ssh -i your-key.pem ubuntu@<public-ip>
```

## Step 3: Run Jenkins Setup Script

Once connected to your EC2 instance:

```bash
# Download the setup script
curl -O https://raw.githubusercontent.com/yourusername/AWS_IAC/main/setup-jenkins.sh

# Or copy-paste the contents from setup-jenkins.sh in this repo

# Make it executable
chmod +x setup-jenkins.sh

# Run it
./setup-jenkins.sh
```

## Step 4: Access Jenkins

1. Get the initial admin password:
```bash
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

2. Open browser and go to:
```
http://<ec2-public-ip>:8080
```

3. Paste the initial admin password

4. Follow the Jenkins setup wizard:
   - Install suggested plugins
   - Create first admin user
   - Configure Jenkins URL

## Step 5: Configure AWS Credentials in Jenkins

After Jenkins is fully set up:

1. **Go to Jenkins Dashboard** → **Manage Jenkins** → **Manage Credentials**
2. **Add Credentials**:
   - Kind: AWS Credentials
   - ID: `aws-credentials`
   - Access Key ID: (from your AWS IAM user)
   - Secret Access Key: (from your AWS IAM user)
3. Click **Create**

## Step 6: Create Jenkins Job for Deployment

1. **New Item** → Enter name (e.g., `vpc-deployment`)
2. **Pipeline job type**
3. **Pipeline** section:
   - **Definition**: Pipeline script from SCM
   - **SCM**: Git
   - **Repository URL**: Your GitHub repo with this code
   - **Branch**: main (or your branch)
4. **Save** and **Build Now**

## Security Considerations

- ⚠️ Restrict SSH security group to your IP
- ⚠️ Change Jenkins admin password immediately
- ⚠️ Don't store credentials in code - use Jenkins Credentials
- ⚠️ Keep Jenkins and plugins updated
- Consider using a bastion host for production

## Troubleshooting

**Jenkins not starting?**
```bash
sudo systemctl status jenkins
sudo journalctl -u jenkins -n 50
```

**AWS CLI not configured?**
```bash
aws configure
# Enter your IAM credentials
```

**CloudFormation permission denied?**
Ensure your IAM user has these permissions:
- `cloudformation:*`
- `ec2:*`
- `iam:PassRole`