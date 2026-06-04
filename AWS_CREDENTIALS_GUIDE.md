# AWS Credentials Guide for Jenkins

## What Credentials Do You Need?

For Jenkins to deploy CloudFormation templates, you need:
- **AWS Access Key ID** (looks like: `AKIA...`)
- **AWS Secret Access Key** (looks like: `a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6...`)

These come from an **IAM User** in your AWS account.

---

## Step 1: Get AWS Credentials from AWS Console

### Option A: If you already have credentials

You can use existing credentials, but make sure they have the right permissions.

### Option B: Create new credentials (Recommended)

1. **Login to AWS Console**: https://console.aws.amazon.com

2. Go to **IAM** → **Users**

3. Click on your username (or create a new user if needed)

4. Click **Security credentials** tab

5. Under "Access keys" section, click **Create access key**

6. Choose **Application running outside AWS** (for Jenkins)

7. Click **Next**

8. Add description (optional): "Jenkins VPC Deployment"

9. Click **Create access key**

10. **IMPORTANT**: Copy and save both:
    - **Access Key ID**
    - **Secret Access Key**
    
    ⚠️ **You can only see the Secret Access Key once!** Save it somewhere safe.

---

## Step 2: Verify IAM User Has Required Permissions

Your IAM user **MUST** have these permissions:

1. From the IAM user page, click **Add permissions** → **Attach policies directly**

2. Search for and attach these **AWS managed policies**:
   - `AWSCloudFormationFullAccess`
   - `AmazonEC2FullAccess`
   - `IAMFullAccess` (or just `iam:PassRole` for minimal permissions)

Or create a **custom policy** with:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "cloudformation:*",
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": "ec2:*",
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": "iam:PassRole",
            "Resource": "*"
        }
    ]
}
```

---

## Step 3: Add Credentials to Jenkins

Now that you have the credentials, add them to Jenkins:

1. **Jenkins Dashboard** → **Manage Jenkins** (left sidebar)

2. Click **Manage Credentials**

3. Click **System** (left sidebar)

4. Click **Global credentials (unrestricted)**

5. Click **+ Add Credentials** (top right or left sidebar)

### Fill in the form:

| Field | Value |
|-------|-------|
| **Kind** | AWS Credentials |
| **ID** | `aws-credentials` ⚠️ **IMPORTANT: Must be exactly this** |
| **Description** | AWS Credentials for VPC Deployment |
| **Access Key ID** | Paste your Access Key ID from Step 1 |
| **Secret Access Key** | Paste your Secret Access Key from Step 1 |
| **Scope** | Global (unrestricted) |

6. Click **Create**

---

## Step 4: Verify in Jenkinsfile

Your `Jenkinsfile` should reference this credential:

Look for this line in your Jenkinsfile:
```groovy
environment {
    AWS_CREDENTIALS = credentials('aws-credentials')
    TEMPLATE_FILE = 'vpc-stack.yaml'
}
```

The `credentials('aws-credentials')` matches the ID you created in Step 3.

---

## Complete Visual Example

### AWS Console (Get Credentials):
```
AWS Console 
  → IAM 
    → Users 
      → [Your Username] 
        → Security credentials 
          → Access keys 
            → Create access key
              → Save Access Key ID & Secret Access Key
```

### Jenkins (Add Credentials):
```
Jenkins Dashboard
  → Manage Jenkins
    → Manage Credentials
      → System
        → Global credentials (unrestricted)
          → + Add Credentials
            → Kind: AWS Credentials
            → ID: aws-credentials
            → Paste Access Key ID
            → Paste Secret Access Key
            → Create
```

---

## Security Best Practices

⚠️ **Important Security Tips:**

1. **Never commit credentials to Git**
   - Always use Jenkins Credentials Store (what we just did)
   - Never paste credentials in Jenkinsfile or code

2. **Use minimal permissions**
   - Don't use root/admin credentials
   - Create a dedicated IAM user for Jenkins with only needed permissions

3. **Rotate credentials regularly**
   - Delete old access keys
   - Create new ones periodically

4. **Monitor credential usage**
   - Check CloudTrail logs for suspicious activity
   - Delete unused access keys

5. **Different credentials for different environments**
   - Dev: One set of credentials
   - Prod: Different set with limited permissions

---

## Troubleshooting

**"The security token included in the request is invalid"**
- Check if Secret Access Key is correct (copy again from AWS Console)
- Check if Access Key ID is correct

**"User: arn:aws:iam::... is not authorized to perform: cloudformation:CreateStack"**
- IAM user doesn't have CloudFormation permissions
- Go back to IAM and attach `AWSCloudFormationFullAccess` policy

**"Credentials not found in Jenkins"**
- Check credential ID is exactly `aws-credentials` (case-sensitive)
- Verify it's in Global credentials scope

---

## Next Steps

Once credentials are added:

1. Create a Jenkins Pipeline job pointing to your GitHub repo
2. Run a test build with ACTION: `VALIDATE`
3. If successful, deploy with ACTION: `CREATE`

Good luck! 🚀
