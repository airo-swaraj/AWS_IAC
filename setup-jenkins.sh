#!/bin/bash

##############################################################################
# Jenkins Installation Script for Ubuntu
# Run this script on your EC2 instance after SSH connection
# Usage: sudo ./setup-jenkins.sh
##############################################################################

set -e  # Exit on any error

echo "============================================"
echo "Jenkins Setup Script for Ubuntu"
echo "============================================"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
   echo "ERROR: This script must be run as root (use sudo)"
   exit 1
fi

# Update system
echo -e "\n[1/6] Updating system packages..."
apt-get update
apt-get upgrade -y

# Install Java
echo -e "\n[2/6] Installing Java..."
apt-get install -y openjdk-11-jdk

# Verify Java installation
echo "Java version:"
java -version

# Add Jenkins repository (modern method for Ubuntu 22.04+)
echo -e "\n[3/6] Adding Jenkins repository..."
mkdir -p /usr/share/keyrings

# Remove old Jenkins repository if it exists
rm -f /etc/apt/sources.list.d/jenkins.list
rm -f /usr/share/keyrings/jenkins-archive-keyring.gpg

# Download and convert Jenkins GPG key
wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io.key | gpg --dearmor -o /usr/share/keyrings/jenkins-archive-keyring.gpg

# Add Jenkins repository with signed-by parameter
echo "deb [signed-by=/usr/share/keyrings/jenkins-archive-keyring.gpg] https://pkg.jenkins.io/debian-stable binary/" | tee /etc/apt/sources.list.d/jenkins.list > /dev/null

apt-get update

# Install Jenkins
echo -e "\n[4/6] Installing Jenkins..."
apt-get install -y jenkins

# Start Jenkins service
echo -e "\n[5/6] Starting Jenkins service..."
systemctl start jenkins
systemctl enable jenkins

# Verify Jenkins is running
echo -e "\n[6/6] Verifying Jenkins installation..."
sleep 5  # Wait for Jenkins to start

if systemctl is-active --quiet jenkins; then
    echo "✓ Jenkins is running successfully!"
else
    echo "✗ Jenkins failed to start. Check logs:"
    systemctl status jenkins
    exit 1
fi

# Get and display initial admin password
echo ""
echo "============================================"
echo "Jenkins Setup Complete!"
echo "============================================"
echo ""
echo "📋 Initial Admin Password (save this):"
echo "============================================"
cat /var/lib/jenkins/secrets/initialAdminPassword
echo ""
echo "============================================"
echo ""
echo "🌐 Access Jenkins at:"
echo "   http://$(hostname -I | awk '{print $1}'):8080"
echo ""
echo "📝 Next Steps:"
echo "   1. Open Jenkins URL in browser"
echo "   2. Paste the initial admin password above"
echo "   3. Complete the setup wizard"
echo "   4. Install suggested plugins"
echo "   5. Create your first admin user"
echo ""
echo "🔐 Configure AWS Credentials:"
echo "   - Jenkins Dashboard → Manage Jenkins → Manage Credentials"
echo "   - Add AWS credentials with ID: 'aws-credentials'"
echo ""
echo "============================================"
