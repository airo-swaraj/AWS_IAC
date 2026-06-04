#!/bin/bash

##############################################################################
# Jenkins Cleanup Script - Remove all Jenkins installations
# Run this to clean up before installing Jenkins from website
# Usage: sudo ./remove-jenkins.sh
##############################################################################

set -e

echo "============================================"
echo "Jenkins Cleanup Script"
echo "============================================"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
   echo "ERROR: This script must be run as root (use sudo)"
   exit 1
fi

echo -e "\n[1/5] Stopping Jenkins service..."
systemctl stop jenkins 2>/dev/null || true
systemctl disable jenkins 2>/dev/null || true

echo -e "\n[2/5] Removing Jenkins package..."
apt-get remove -y jenkins 2>/dev/null || true
apt-get purge -y jenkins 2>/dev/null || true

echo -e "\n[3/5] Removing Jenkins repositories and keys..."
rm -f /etc/apt/sources.list.d/jenkins.list
rm -f /usr/share/keyrings/jenkins-archive-keyring.gpg

echo -e "\n[4/5] Removing Jenkins configuration and home directories..."
rm -rf /var/lib/jenkins
rm -rf /var/cache/jenkins
rm -rf /var/log/jenkins

echo -e "\n[5/5] Removing Jenkins user and group..."
userdel -r jenkins 2>/dev/null || true
groupdel jenkins 2>/dev/null || true

echo -e "\n============================================"
echo "✓ Jenkins cleanup complete!"
echo "============================================"
echo ""
echo "Optional: Remove Java if not needed:"
echo "   sudo apt-get remove -y openjdk-11-jdk"
echo "   sudo apt-get autoremove -y"
echo ""
echo "Then update apt cache:"
echo "   sudo apt-get update"
echo ""
echo "Now you can install Jenkins from the website."
echo "============================================"
