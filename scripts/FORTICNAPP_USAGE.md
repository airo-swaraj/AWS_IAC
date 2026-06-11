# FortiCNAPP IaC Scanner - Reusable Script

This script provides a **portable, reusable way** to scan Infrastructure-as-Code files with FortiCNAPP security scanning. You can use it in any Jenkins pipeline or CI/CD system.

## Features

✅ Scan single files or entire folders  
✅ Support for multiple file types: YAML, JSON, Terraform  
✅ Glob pattern support (`*.yaml`)  
✅ Portable across any pipeline  
✅ Beautiful HTML report generation  
✅ Graceful error handling  
✅ Verbose logging mode  

## Setup

### 1. Copy Script to Your Project

```bash
# Copy to your pipeline project
cp scripts/forticnapp-scan.sh /path/to/your/project/scripts/
chmod +x /path/to/your/project/scripts/forticnapp-scan.sh
```

### 2. Set Up Jenkins Credentials

Create three Jenkins secret text credentials:
- `FORTICNAPP_ACCESS_KEY` - Your FortiCNAPP API Access Key
- `FORTICNAPP_SECRET_KEY` - Your FortiCNAPP API Secret Key
- `FORTICNAPP_ACCOUNT` - Your FortiCNAPP Account ID (e.g., 719551)

## Usage

### Basic Usage in Jenkinsfile

```groovy
stage('Scan IaC with FortiCNAPP') {
    steps {
        withCredentials([
            string(credentialsId: 'FORTICNAPP_ACCESS_KEY', variable: 'LW_ACCESS'),
            string(credentialsId: 'FORTICNAPP_SECRET_KEY', variable: 'LW_SECRET'),
            string(credentialsId: 'FORTICNAPP_ACCOUNT', variable: 'LACEWORK_ACCOUNT')
        ]) {
            sh '''
                chmod +x scripts/forticnapp-scan.sh
                
                export LW_ACCESS="${LW_ACCESS}"
                export LW_SECRET="${LW_SECRET}"
                export LACEWORK_ACCOUNT="${LACEWORK_ACCOUNT}"
                export SCAN_REPORT_DIR="forticnapp-scan-reports"
                
                # Scan single file
                ./scripts/forticnapp-scan.sh vpc-stack.yaml
                
                # Or scan entire folder
                ./scripts/forticnapp-scan.sh ./templates
                
                # Or scan multiple patterns
                ./scripts/forticnapp-scan.sh *.yaml *.json
            '''
        }
    }
}
```

### Scan Multiple Files

```bash
# Scan all YAML files in current directory
./forticnapp-scan.sh *.yaml

# Scan entire templates folder
./forticnapp-scan.sh ./templates

# Scan multiple folders
./forticnapp-scan.sh ./cloudformation ./terraform

# Scan specific files
./forticnapp-scan.sh vpc.yaml db.yaml app.yaml
```

### Advanced Usage

```bash
# Verbose output for debugging
VERBOSE=true ./forticnapp-scan.sh vpc.yaml

# Continue scanning even if one file fails
CONTINUE_ON_ERROR=true ./forticnapp-scan.sh *.yaml

# Custom output directory
./forticnapp-scan.sh -o /tmp/security-reports vpc.yaml

# Combine options
./forticnapp-scan.sh -v -o reports -c *.yaml
```

### Script Options

```bash
./forticnapp-scan.sh --help

# -h, --help         Show help message
# -v, --verbose      Enable verbose/debug output
# -o, --output DIR   Set output directory for reports
```

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `LW_ACCESS` | ✅ Yes | FortiCNAPP API Access Key |
| `LW_SECRET` | ✅ Yes | FortiCNAPP API Secret Key |
| `LACEWORK_ACCOUNT` | ✅ Yes | FortiCNAPP Account ID |
| `SCAN_REPORT_DIR` | ❌ No | Output directory (default: `forticnapp-scan-reports`) |
| `CONTINUE_ON_ERROR` | ❌ No | Continue if scan fails (default: `false`) |
| `VERBOSE` | ❌ No | Enable verbose output (default: `false`) |

## Output

The script generates:

```
forticnapp-scan-reports/
├── vpc-stack.yaml.scan.json      # JSON scan results
├── templates-app.yaml.scan.json   # Multiple scans
└── scan-report.html               # HTML report for viewing
```

### HTML Report

A beautiful, interactive HTML report is generated at:
```
forticnapp-scan-reports/scan-report.html
```

Open in any browser to view:
- Scan summary
- Files scanned
- Issues found per file
- Detailed scan results

## Integration Examples

### Example 1: Multi-Environment Scanning

```groovy
pipeline {
    agent any
    
    stages {
        stage('Scan Dev Templates') {
            steps {
                withCredentials([...]) {
                    sh '''
                        ./scripts/forticnapp-scan.sh -o reports/dev ./templates/dev
                    '''
                }
            }
        }
        
        stage('Scan Prod Templates') {
            steps {
                withCredentials([...]) {
                    sh '''
                        ./scripts/forticnapp-scan.sh -o reports/prod ./templates/prod
                    '''
                }
            }
        }
    }
}
```

### Example 2: Multiple IaC Frameworks

```groovy
stage('Security Scan') {
    steps {
        withCredentials([...]) {
            sh '''
                chmod +x scripts/forticnapp-scan.sh
                
                # Scan CloudFormation
                ./scripts/forticnapp-scan.sh -o reports/cfn ./cloudformation
                
                # Scan Terraform
                ./scripts/forticnapp-scan.sh -o reports/tf ./terraform
                
                # Scan Kubernetes
                ./scripts/forticnapp-scan.sh -o reports/k8s ./kubernetes
            '''
        }
    }
}
```

### Example 3: Terraform Modules

```groovy
stage('Scan Terraform Modules') {
    steps {
        withCredentials([...]) {
            sh '''
                ./scripts/forticnapp-scan.sh \
                  ./modules/vpc \
                  ./modules/database \
                  ./modules/security \
                  -o terraform-scans
            '''
        }
    }
}
```

## Error Handling

The script gracefully handles:
- Missing credentials → Exits with error message
- Invalid files → Logs warning, continues
- API failures → Exits gracefully (can use `CONTINUE_ON_ERROR=true`)
- No files found → Clear error message

## Archiving Reports

Add to your Jenkinsfile post-actions:

```groovy
post {
    always {
        archiveArtifacts artifacts: 'forticnapp-scan-reports/**/*',
                        allowEmptyArchive: true
        
        // Optional: Publish HTML report
        publishHTML([
            reportDir: 'forticnapp-scan-reports',
            reportFiles: 'scan-report.html',
            reportName: 'FortiCNAPP Security Scan'
        ])
    }
}
```

## Troubleshooting

### "Access Key is null" Error

Check FortiCNAPP subscription status:
1. Log into https://www.forticloud.com/
2. Verify subscription is active
3. Generate new API credentials
4. Update Jenkins credentials

### "Unable to process JSON"

Usually means the API request format is wrong. Enable verbose mode:
```bash
VERBOSE=true ./forticnapp-scan.sh vpc.yaml
```

### Script Permission Denied

Make script executable:
```bash
chmod +x scripts/forticnapp-scan.sh
```

## Performance Tips

- **Parallel scanning**: Run multiple scans in separate stages
- **Large folders**: Use glob patterns to scan specific file types
- **CI/CD**: Archive reports for auditing

## Supported IaC Formats

- CloudFormation (`.yaml`, `.yml`, `.json`)
- Terraform (`.tf`)
- Kubernetes manifests (`.yaml`, `.yml`)
- AWS SAM templates
- Any JSON/YAML-based IaC

## License

This script is provided as-is for use with FortiCNAPP.

## Support

For issues with the script, check:
1. FortiCNAPP subscription status
2. API credentials validity
3. Network connectivity to FortiCloud
4. File format compatibility

