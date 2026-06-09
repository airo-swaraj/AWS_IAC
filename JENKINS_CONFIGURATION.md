# Jenkins Setup & Configuration Guide

## Step 1: Access Jenkins Web UI

1. Open your browser and go to:
   ```
   http://<your-ec2-public-ip>:8080
   ```

2. You should see the Jenkins unlock page

3. Get the initial admin password from your VM:
   ```bash
   sudo cat /var/lib/jenkins/secrets/initialAdminPassword
   ```

4. Copy-paste this password into Jenkins and click **Continue**

---

## Step 2: Install Plugins

Jenkins will ask "Which plugins would you like to install?"

1. Click **Install suggested plugins** (recommended)
   - This will install common plugins needed for our setup

2. Wait for installation to complete (takes 2-3 minutes)

---

## Step 3: Create First Admin User

After plugins install:

1. **Username**: Enter your desired username (e.g., `admin`)
2. **Password**: Enter a strong password
3. **Full name**: Enter your name
4. **Email**: Enter your email address
5. Click **Save and Continue**

6. On "Instance Configuration" page, keep the default URL and click **Save and Finish**

---

## Step 4: Add AWS Credentials to Jenkins

Now you're in Jenkins Dashboard.

### Create AWS Credentials:

1. Click **Manage Jenkins** (left sidebar)
2. Click **Manage Credentials**
3. Click **System** (left sidebar)
4. Click **Global credentials (unrestricted)**
5. Click **+ Add Credentials** (top right)

Fill in the form:
- **Kind**: AWS Credentials
- **ID**: `aws-credentials` (IMPORTANT: must match this exact name)
- **Description**: AWS Credentials for VPC Deployment
- **Access Key ID**: (Get from your AWS IAM user)
- **Secret Access Key**: (Get from your AWS IAM user)

6. Click **Create**

> **How to get AWS credentials:**
> - Go to AWS Console → IAM → Users → Your User
> - Click **Security Credentials** tab
> - Click **Create Access Key** (if you don't have one)
> - Copy the Access Key ID and Secret Access Key
> - ⚠️ **Important**: The IAM user needs these permissions:
>   - cloudformation:*
>   - ec2:*
>   - iam:PassRole

---

## Step 5: Create Jenkins Pipeline Job

1. From Jenkins Dashboard, click **+ New Item** (left sidebar)

2. **Job name**: Enter `vpc-deployment` (or any name you like)

3. **Job type**: Select **Pipeline** and click **OK**

---

## Step 6: Configure Pipeline Job

On the configuration page:

### General Section:
- Check: **Discard old builds**
  - Max # of builds to keep: `10`

### Build Triggers:
- Leave as default (we'll run manually)

### Pipeline Section:

**Definition**: Select **Pipeline script from SCM**

**SCM**: Select **Git**

Fill in:
- **Repository URL**: 
  ```
  https://github.com/your-username/AWS_IAC.git
  ```
  (Replace with your actual repo URL)

- **Branch Specifier**: `*/main` (or your branch name)

- **Script Path**: `Jenkinsfile` (this is the file in your repo)

Click **Save**

---

## Step 7: Test the Pipeline

1. From the job page, click **Build Now** (left sidebar)

2. You'll see a build starting (#1)

3. Click on the build number to see the build logs

4. The pipeline will:
   - Checkout your code
   - Validate the CloudFormation template
   - Display options to create/update/delete stack

---

## Step 8: Run the Deployment

After the first build completes:

1. Click **Build with Parameters** (left sidebar)

2. Configure the parameters:
   - **AWS_REGION**: `us-east-1` (or your preferred region)
   - **STACK_NAME**: `vpc-stack` (or your stack name)
   - **ENVIRONMENT**: `production` (or your environment)
   - **ACTION**: Choose one:
     - `VALIDATE` - Just validate the template (safe, no resources created)
     - `CREATE` - Create new VPC stack
     - `UPDATE` - Update existing stack
     - `DELETE` - Delete the stack
   - **VPC_CIDR**: `10.0.0.0/16` (or your CIDR block)
   - Keep subnet CIDRs as default or customize

3. Click **Build**

4. Monitor the build logs to see:
   - Template validation
   - CloudFormation stack creation/update status
   - Any errors or warnings

---

## Step 9: Verify VPC Created

After successful build:

1. Go to **AWS Console** → **VPC** → **Your VPCs**
2. You should see a new VPC with your environment name
3. Check subnets, security groups, internet gateway, etc.

---

## Step 10: View CloudFormation Outputs

In Jenkins logs, you'll see CloudFormation outputs like:
```
VPC ID: vpc-xxxxxx
Public Subnet 1: subnet-xxxxx
Private Subnet 1: subnet-xxxxx
Security Group IDs: sg-xxxxx
```

Save these for later reference!

---

## Troubleshooting

**Build fails with "credentials not found"?**
- Verify credentials ID is exactly `aws-credentials`
- Check IAM user has required permissions

**AWS CLI command not found?**
- Install AWS CLI on Jenkins machine:
  ```bash
  sudo apt-get install -y awscli
  ```

**CloudFormation fails?**
- Check IAM user permissions in AWS Console
- Verify CIDR blocks don't conflict with existing VPCs

**Jenkins won't start?**
- Check logs: `sudo journalctl -u jenkins -n 50`
- Verify Java is installed: `java -version`

---

## Next Steps

✅ Now your Jenkins is fully set up to deploy AWS infrastructure!

You can:
- Run deployments by clicking **Build with Parameters**
- Schedule automatic deployments (if needed)
- Add more CloudFormation templates for other resources
- Set up webhooks for automatic builds on Git push

---
