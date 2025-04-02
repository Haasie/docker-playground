# Azure Docker Playground Administrator Guide

This guide provides comprehensive instructions for administrators to deploy, configure, maintain, and troubleshoot the Azure Docker Playground environment. Follow these steps carefully to ensure a successful production deployment.

## Table of Contents

1. [Initial Setup](#initial-setup)
2. [Production Deployment](#production-deployment)
3. [User Management](#user-management)
4. [Maintenance Tasks](#maintenance-tasks)
5. [Troubleshooting](#troubleshooting)
6. [Security Considerations](#security-considerations)
7. [Backup and Recovery](#backup-and-recovery)
8. [Support and Feedback](#support-and-feedback)

## Initial Setup

### Prerequisites

- Azure subscription with Contributor access
- Azure CLI (version 2.40.0 or later) installed locally
- Git installed locally
- SSH client for remote access

### Environment Configuration

1. Clone the repository:
   ```bash
   git clone https://github.com/your-org/docker-playground.git
   cd docker-playground
   ```

2. Create the `.env` file with required variables:
   ```bash
   cat > .env << EOF
   RESOURCE_GROUP=adp-rg
   LOCATION=westeurope
   ENVIRONMENT_NAME=dev
   GUI_VM_NAME=adp-dev-gui-vm
   ACR_NAME=adpdevacr
   ACR_LOGIN_SERVER=adpdevacr.azurecr.io
   ACR_USERNAME=adpdevacr
   # Add your ACR password below
   ACR_PASSWORD=
   EOF
   ```

3. Obtain ACR credentials from Azure Portal or CLI:
   ```bash
   # Get ACR password and update .env file
   ACR_PASSWORD=$(az acr credential show --name $ACR_NAME --query "passwords[0].value" -o tsv)
   sed -i "s/ACR_PASSWORD=/ACR_PASSWORD=$ACR_PASSWORD/" .env
   ```

## Production Deployment

### Pre-Deployment Cleanup

1. Run the cleanup script to remove unnecessary files and prepare for production:
   ```bash
   ./cleanup.sh
   ```

2. Verify the cleanup was successful:
   ```bash
   # Check for any remaining temporary files
   find . -name "*.tmp" -o -name "*.bak" -o -name "*.log"
   ```

### Infrastructure Deployment

1. Deploy the Azure resources:
   ```bash
   # Login to Azure
   az login
   
   # Create resource group if it doesn't exist
   az group create --name $RESOURCE_GROUP --location $LOCATION
   
   # Deploy the VM and related resources
   ./scripts/deploy-infrastructure.sh
   ```

2. Configure the VM environment:
   ```bash
   # Run post-deployment setup
   ./scripts/post-deploy-setup.sh
   ```
   - Select option 2 to set VM password for RDP access
   - Enter the admin username (default: azureadmin)
   - Set a strong password

3. Set up the Docker challenges:
   ```bash
   # Set up challenges with ACR information
   ./scripts/setup-challenges.sh $ACR_NAME $ACR_LOGIN_SERVER
   ```

4. Verify the deployment:
   ```bash
   # Verify VM is running
   az vm show --resource-group $RESOURCE_GROUP --name $GUI_VM_NAME --query powerState -o tsv
   
   # Verify ACR is accessible
   az acr login --name $ACR_NAME
   ```

## User Management

### Creating User Accounts

Use the `create-user.sh` script to create user accounts for participants:

```bash
# SSH into the VM first
az ssh vm --resource-group $RESOURCE_GROUP --name $GUI_VM_NAME --local-user azureadmin

# Then create user accounts
sudo ./scripts/create-user.sh <username> <password>
```

This script will:
- Create a user account with the specified username and password
- Set up the user's environment with necessary files and permissions
- Create desktop shortcuts for accessing the Docker challenges
- Copy the Docker challenges to the user's directory with proper permissions

### Managing User Access

Users can access the VM through one of these methods:

1. **Azure Bastion** (Recommended for production):
   - Navigate to the VM in Azure Portal
   - Click "Connect" > "Bastion"
   - Select RDP as the connection type
   - Enter username and password
   - Click "Connect"

2. **RDP Client** (Alternative):
   - Ensure the VM has a public IP or is accessible via VPN
   - Use an RDP client with the VM's IP address
   - Enter username and password when prompted

## Maintenance Tasks

### Regular Maintenance Schedule

Implement the following maintenance schedule for optimal performance:

| Task | Frequency | Command |
|------|-----------|--------|
| System updates | Weekly | `sudo apt update && sudo apt upgrade -y` |
| Docker cleanup | Monthly | `docker system prune -a --volumes` |
| ACR credential rotation | Quarterly | `az acr credential renew --name $ACR_NAME --password-name password` |
| VM backup | Monthly | `az vm snapshot create --resource-group $RESOURCE_GROUP --name $GUI_VM_NAME-$(date +%Y%m%d) --vm-name $GUI_VM_NAME` |

### Updating the Environment

To update the Docker Playground environment:

1. SSH into the VM:
   ```bash
   az ssh vm --resource-group $RESOURCE_GROUP --name $GUI_VM_NAME --local-user azureadmin
   ```

2. Navigate to the project directory:
   ```bash
   cd ~/azure-docker-playground
   ```

3. Pull the latest changes:
   ```bash
   git pull
   ```

4. Run the update script:
   ```bash
   ./scripts/reset-environment.sh
   ```
   - Select option 1 for a quick reset (Docker resources only)
   - Select option 2 for a full reset (VM redeployment)

### Resetting Challenges

To reset all challenges for a specific user:

```bash
# SSH into the VM
az ssh vm --resource-group $RESOURCE_GROUP --name $GUI_VM_NAME --local-user azureadmin

# Reset challenges for a user
sudo -u <username> bash -c 'cd ~/azure-docker-playground/docker-challenges && for d in */; do cd "$d" && ./reset.sh && cd ..; done'
```

## Troubleshooting

### X11 Display Issues

If users report problems launching graphical applications like Firefox or Chromium:

1. Verify the X11 display fix is applied:
   ```bash
   grep -r "fix-x11-display" /home/<username>/.bashrc
   ```

2. If missing, reapply the fix:
   ```bash
   sudo ansible-playbook /home/azureadmin/azure-docker-playground/ansible/gui-setup.yml --extra-vars "current_user=<username>"
   ```

3. For immediate fix without rerunning the playbook:
   ```bash
   sudo -u <username> bash -c 'echo "export DISPLAY=:10" >> ~/.bashrc && echo "xhost +local:" >> ~/.bashrc'
   ```

### Docker Access Issues

If users can't access Docker:

1. Check if the user is in the docker group:
   ```bash
   groups <username> | grep docker
   ```

2. Add the user to the docker group if needed:
   ```bash
   sudo usermod -aG docker <username>
   sudo systemctl restart docker
   # User needs to log out and back in for changes to take effect
   ```

3. Verify Docker is running:
   ```bash
   sudo systemctl status docker
   ```

### ACR Authentication Issues

If users can't push to ACR:

1. Verify the .env file exists and has correct credentials:
   ```bash
   cat /home/<username>/azure-docker-playground/docker-challenges/.env
   ```

2. Update the ACR credentials if needed:
   ```bash
   # Get the latest ACR password
   ACR_PASSWORD=$(az acr credential show --name $ACR_NAME --query "passwords[0].value" -o tsv)
   
   # Update the .env file
   sudo sed -i "s/ACR_PASSWORD=.*/ACR_PASSWORD=$ACR_PASSWORD/" /home/<username>/azure-docker-playground/docker-challenges/.env
   ```

3. Ensure the user can authenticate with Docker:
   ```bash
   sudo -u <username> bash -c 'docker login $ACR_LOGIN_SERVER -u $ACR_USERNAME -p $ACR_PASSWORD'
   ```

## Security Considerations

### Hardening the Production Environment

1. **Network Security**:
   - Use Azure Bastion for secure VM access instead of public IP
   - Implement Network Security Groups (NSGs) with restrictive rules
   ```bash
   # Remove public IP from VM for enhanced security
   ./scripts/post-deploy-setup.sh
   # Select option 1: Remove public IP from VM
   ```

2. **Access Control**:
   - Limit SSH access to the VM
   - Use Just-In-Time (JIT) VM access in Azure Security Center
   - Implement Azure AD authentication where possible

3. **Sensitive Information Management**:
   - Store ACR credentials securely using Azure Key Vault
   - Rotate credentials regularly (at least quarterly)
   - Use environment variables instead of hardcoded values
   ```bash
   # Set up Azure Key Vault integration
   ./scripts/setup-key-vault.sh $RESOURCE_GROUP
   ```

4. **User Account Security**:
   - Enforce strong password policies
   - Require users to change passwords after initial login
   - Use the principle of least privilege for all accounts
   - The `azureadmin` account should be used only for administrative tasks

### Compliance Checks

Regularly run security compliance checks:

```bash
# Check for security updates
sudo apt update && apt list --upgradable

# Check for exposed ports
sudo netstat -tulpn | grep LISTEN

# Check Docker security
docker info --format '{{json .SecurityOptions}}'
```

## Backup and Recovery

### Regular Backup Strategy

1. **VM Snapshots**:
   ```bash
   # Create a VM snapshot
   az vm snapshot create \
     --resource-group $RESOURCE_GROUP \
     --name $GUI_VM_NAME-backup-$(date +%Y%m%d) \
     --vm-name $GUI_VM_NAME
   ```

2. **Configuration Backup**:
   ```bash
   # Backup important configuration files
   sudo tar -czf /tmp/adp-config-backup-$(date +%Y%m%d).tar.gz \
     /home/azureadmin/azure-docker-playground/ansible \
     /home/azureadmin/azure-docker-playground/scripts \
     /home/azureadmin/azure-docker-playground/.env
   
   # Download the backup
   az vm run-command invoke \
     --resource-group $RESOURCE_GROUP \
     --name $GUI_VM_NAME \
     --command-id RunShellScript \
     --scripts "cat /tmp/adp-config-backup-$(date +%Y%m%d).tar.gz | base64" \
     | jq -r '.value[0].message' | base64 -d > adp-config-backup-$(date +%Y%m%d).tar.gz
   ```

### Disaster Recovery

1. **VM Recovery**:
   ```bash
   # Restore VM from snapshot
   az vm restore --resource-group $RESOURCE_GROUP \
     --name $GUI_VM_NAME \
     --restore-from-snapshot-id /subscriptions/<subscription-id>/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Compute/snapshots/$GUI_VM_NAME-backup-<date>
   ```

2. **Configuration Restoration**:
   ```bash
   # Upload and extract backup
   cat adp-config-backup-<date>.tar.gz | base64 | \
   az vm run-command invoke \
     --resource-group $RESOURCE_GROUP \
     --name $GUI_VM_NAME \
     --command-id RunShellScript \
     --scripts "cat > /tmp/backup.b64 && base64 -d /tmp/backup.b64 > /tmp/backup.tar.gz && tar -xzf /tmp/backup.tar.gz -C /"
   ```

## Support and Feedback

### Getting Help

For technical support or to provide feedback:

- **GitHub Issues**: Create an issue in the GitHub repository with detailed information about your problem or suggestion
- **Email Support**: Contact the maintainers at support@example.com
- **Documentation**: Refer to the [USER_GUIDE.md](./USER_GUIDE.md) for end-user documentation

### Contributing

To contribute to the project:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request with a clear description of the changes

### Version History

Keep track of environment versions:

```bash
# Create a version file after each major update
echo "Azure Docker Playground v1.0.0 - $(date)" > /home/azureadmin/azure-docker-playground/VERSION
```
