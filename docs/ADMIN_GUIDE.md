# Azure Docker Playground Administrator Guide

This guide provides comprehensive instructions for administrators to deploy, configure, maintain, and troubleshoot the Azure Docker Playground environment. Follow these steps carefully to ensure a successful production deployment.

> **IMPORTANT**: Commands in this guide are run in two different locations:
> - **[LOCAL]** - Run on your local development machine
> - **[VM]** - Run on the Azure VM after connecting via Azure Bastion
>
> **NOTE**: This environment is configured for secure access via Azure Bastion only. Direct SSH connections from your local machine to the VM are not possible.

## Table of Contents
- Initial Setup
- Production Deployment
- User Management
- Maintenance Tasks
- Troubleshooting
- Security Considerations
- Backup and Recovery
- Support and Feedback

## Initial Setup

### Prerequisites
- Azure subscription with Contributor access
- Azure CLI (version 2.40.0 or later) installed locally
- Git installed locally
- SSH client for remote access

### Environment Configuration
1. **[LOCAL]** Clone the repository:
   ```bash
   git clone <https://github.com/your-org/docker-playground.git> # Replace with your repo URL
   cd docker-playground
   ```
2. **[LOCAL]** Create the `.env` file with required variables:
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
3. **[LOCAL]** Obtain ACR credentials from Azure Portal or CLI:
   ```bash
   # Get ACR password and update .env file
   ACR_PASSWORD=$(az acr credential show --name $ACR_NAME --query "passwords[0].value" -o tsv)
   sed -i "s/ACR_PASSWORD=/ACR_PASSWORD=$ACR_PASSWORD/" .env
   ```

## Production Deployment

This section outlines the streamlined 5-step process to deploy the Azure Docker Playground environment using the consolidated scripts.

### Step 1: Prerequisites & Clone Repository [LOCAL]
1. Ensure you have the following installed on your **local machine**:
   - Azure CLI (version 2.40.0 or later)
   - Git
   - An SSH client and an SSH key pair (e.g., `~/.ssh/id_rsa` and `~/.ssh/id_rsa.pub`). If you don't have one, generate it using `ssh-keygen -t rsa -b 4096`.
2. Clone the repository:
   ```bash
   # [LOCAL] Clone the repository
   git clone <https://github.com/your-org/docker-playground.git> # Replace with your repo URL
   cd docker-playground
   ```
3. Create or update the `.env` file in the root of the cloned repository. Make sure to replace `"YOUR_SSH_KEY_HERE"` with the *contents* of your public SSH key file (`~/.ssh/id_rsa.pub`).
   ```bash
   # [LOCAL] Create/update .env file
   cat > .env << EOF
   RESOURCE_GROUP=adp-rg         # Choose a name for your resource group
   LOCATION=westeurope         # Choose an Azure region
   ENVIRONMENT_NAME=prod         # Environment name (e.g., prod, staging)
   ADMIN_USERNAME=azureadmin     # Initial admin username for the VM
   ADMIN_SSH_KEY="$(cat ~/.ssh/id_rsa.pub 2>/dev/null || echo "YOUR_SSH_KEY_HERE")"
   EOF
   ```
   - Review and adjust other variables in `.env` if needed.

### Step 2: Deploy Azure Infrastructure & Initial VM Config [LOCAL]
1. Run the main deployment script from your **local machine**:
   ```bash
   # [LOCAL] Login to Azure if needed
   az login

   # [LOCAL] Run the deployment script
   ./scripts/deploy-azure-playground.sh
   ```
2. This script will:
   - Create the Azure resource group if it doesn't exist.
   - Deploy all necessary Azure resources (VM, VNet, Bastion, ACR) using Bicep.
   - Retrieve ACR credentials and save them to the `.env` file.
   - **Remove the Public IP address** from the VM for security.
   - **Prompt you to set a password** for the `ADMIN_USERNAME`. This password is required for RDP connections via Azure Bastion.
3. Note the outputs from the script, especially the VM name and admin username.

### Step 3: Connect to VM & Transfer Project Files [LOCAL/PORTAL]
1. Connect to the deployed VM using **Azure Bastion** from the Azure Portal:
   - Navigate to the Azure Portal (<https://portal.azure.com>).
   - Find the Virtual Machine resource deployed in Step 2.
   - Click "Connect" -> "Bastion".
   - Select Connection Type: **RDP**.
   - Enter the `ADMIN_USERNAME` (e.g., `azureadmin`).
   - Enter the **password you set** during Step 2.
   - Click "Connect".
2. Once connected to the VM's desktop environment via Bastion, use the **Bastion file upload feature**:
   - Click the "Upload file" icon in the Bastion session toolbar.
   - Select the **entire `docker-playground` directory** from your local machine.
   - This will upload the project files (including `ansible/`, `scripts/`, `.env`, etc.) to the admin user's home directory on the VM (e.g., `/home/azureadmin/docker-playground`).

### Step 4: Configure VM Environment [VM]
Perform these commands **inside the VM** via the Bastion RDP session:
1. Open a terminal on the VM (e.g., using the Desktop shortcut if available, or Applications -> System Tools -> LXTerminal).
2. Navigate to the uploaded project directory:
   ```bash
   # [VM] Change to the project directory
   cd ~/docker-playground
   ```
3. Make the Ansible runner script executable:
   ```bash
   # [VM] Make script executable
   chmod +x scripts/run-ansible-local.sh
   ```
4. Run the Ansible playbooks sequentially using the local runner script. This script handles running Ansible correctly on the VM itself.
   ```bash
   # [VM] Install Docker
   ./scripts/run-ansible-local.sh ansible/docker.yml

   # [VM] Setup GUI Environment (Desktop, xRDP fixes, Firefox fixes)
   ./scripts/run-ansible-local.sh ansible/gui-setup.yml

   # [VM] Setup Docker Challenges (Reads ACR info from the uploaded .env file)
   # Ensure the .env file (uploaded in Step 3) is present in ~/docker-playground
   source .env # Load ACR variables into the current shell session
   ./scripts/run-ansible-local.sh ansible/challenges.yml --extra-vars "acr_name=$ACR_NAME acr_login_server=$ACR_LOGIN_SERVER acr_password='$ACR_PASSWORD'"
   ```
   - *Note:* The `challenges.yml` playbook expects the `.env` file (containing ACR credentials) to be present in the `~/docker-playground` directory on the VM. The upload in Step 3 ensures this.

### Step 5: User Management (Optional) [VM]
For providing access to participants without sharing the admin credentials:
1. Run the user creation script **on the VM**:
   ```bash
   # [VM] Navigate to scripts directory if needed
   cd ~/docker-playground/scripts

   # [VM] Create a user (replace <username> and <password>)
   sudo ./create-user.sh <username> <password>
   ```
2. Provide the created `<username>` and `<password>` to the participant. They can connect using the same Azure Bastion RDP method described in Step 3, but using their own credentials.

### Deployment Complete
The Azure Docker Playground environment is now fully deployed and configured.

## User Management
### Creating User Accounts
Use the `create-user.sh` script to create user accounts for participants:
1. **[VM]** Connect to the VM via Azure Bastion:
   **To connect via Azure Bastion:**
   1. Go to the Azure Portal (<https://portal.azure.com>)
   2. Navigate to the VM resource (`adp-dev-gui-vm`)
   3. Click on "Connect" and select "Bastion"
   4. Enter the username (`azureadmin`) and password you set earlier
   5. Click "Connect"

2. **[VM]** Once connected to the VM, create user accounts:
   ```bash
   # Navigate to the scripts directory
   cd ~/azure-docker-playground/scripts

   # Create a new user account
   sudo ./create-user.sh <username> <password>
   ```
This script will:
- Create a user account with the specified username and password
- Set up the user's environment with necessary files and permissions
- Create desktop shortcuts for accessing the Docker challenges
- Copy the Docker challenges to the user's directory with proper permissions

## Managing User Access
Users can access the VM through Azure Bastion only:
1. Navigate to the VM in Azure Portal (<https://portal.azure.com>)
2. Click "Connect" > "Bastion"
3. Select RDP as the connection type
4. Enter the username and password provided by the administrator
5. Click "Connect"

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
1. **[LOCAL]** Pull the latest changes from your Git repository:
   ```bash
   cd /path/to/your/local/docker-playground
   git pull origin main
   ```
2. **[LOCAL/PORTAL]** Connect to the VM via Bastion.
3. **[LOCAL/PORTAL]** Upload the updated project files/directories (e.g., `ansible/`, `scripts/`) to the VM using Bastion file transfer, overwriting existing files.
4. **[VM]** Re-run the relevant Ansible playbooks using `run-ansible-local.sh` as shown in Step 4 of the deployment process to apply the changes.

### Resetting the Environment
Refer to the `reset-environment.sh` script for options to reset the VM or Docker environment. (Further details may need to be added here depending on the final state of the reset script).

### Destroying the Environment
To completely remove all deployed Azure resources:
1. **[LOCAL]** Run the destroy script:
   ```bash
   # [LOCAL] Ensure RESOURCE_GROUP is set in your environment or .env file
   source .env
   ./scripts/destroy-env.sh $RESOURCE_GROUP
   ```

### Available Scripts Summary
- **[LOCAL]** `scripts/deploy-azure-playground.sh`: Deploys Azure resources and performs initial VM configuration (IP removal, password set).
- **[VM]** `scripts/run-ansible-local.sh`: Helper script to execute Ansible playbooks correctly on the VM itself.
- **[VM]** `scripts/create-user.sh`: Creates dedicated user accounts for participants.
- **[LOCAL]** `scripts/destroy-env.sh`: Removes all Azure resources associated with the deployment.
- **[VM/LOCAL]** `scripts/reset-environment.sh`: Provides options to reset the VM or Docker environment (details TBC).

## Troubleshooting
### X11 Display Issues
If users report problems launching graphical applications like Firefox or Chromium:
1. **[VM]** Connect to the VM via Azure Bastion:
   **To connect via Azure Bastion:**
   1. Go to the Azure Portal (<https://portal.azure.com>)
   2. Navigate to the VM resource (`adp-dev-gui-vm`)
   3. Click on "Connect" and select "Bastion"
   4. Enter the username (`azureadmin`) and password you set earlier
   5. Click "Connect"

2. **[VM]** Verify the X11 display fix is applied:
   ```bash
   grep -r "fix-x11-display" /home/<username>/.bashrc
   ```
3. **[VM]** If missing, reapply the fix:
   ```bash
   sudo ansible-playbook /home/azureadmin/azure-docker-playground/ansible/gui-setup.yml --extra-vars "current_user=<username>"
   ```
4. **[VM]** For immediate fix without rerunning the playbook:
   ```bash
   sudo -u <username> bash -c 'echo "export DISPLAY=:10" >> ~/.bashrc && echo "xhost +local:" >> ~/.bashrc'
   ```

### Docker Access Issues
If users can't access Docker:
1. **[VM]** Connect to the VM via Azure Bastion:
   **To connect via Azure Bastion:**
   1. Go to the Azure Portal (<https://portal.azure.com>)
   2. Navigate to the VM resource (`adp-dev-gui-vm`)
   3. Click on "Connect" and select "Bastion"
   4. Enter the username (`azureadmin`) and password you set earlier
   5. Click "Connect"

2. **[VM]** Check if the user is in the docker group:
   ```bash
   groups <username> | grep docker
   ```
3. **[VM]** Add the user to the docker group if needed:
   ```bash
   sudo usermod -aG docker <username>
   sudo systemctl restart docker
   # User needs to log out and back in for changes to take effect
   ```
4. **[VM]** Verify Docker is running:
   ```bash
   sudo systemctl status docker
   ```

### ACR Authentication Issues
If users can't push to ACR:
1. **[VM]** Connect to the VM via Azure Bastion:
   **To connect via Azure Bastion:**
   1. Go to the Azure Portal (<https://portal.azure.com>)
   2. Navigate to the VM resource (`adp-dev-gui-vm`)
   3. Click on "Connect" and select "Bastion"
   4. Enter the username (`azureadmin`) and password you set earlier
   5. Click "Connect"

2. **[VM]** Verify the .env file exists and has correct credentials:
   ```bash
   cat /home/<username>/azure-docker-playground/docker-challenges/.env
   ```
3. **[LOCAL]** Get the latest ACR password:
   ```bash
   # Get the latest ACR password
   ACR_PASSWORD=$(az acr credential show --name $ACR_NAME --query "passwords[0].value" -o tsv)
   echo $ACR_PASSWORD  # Note this password for the next step
   ```
4. **[VM]** Update the .env file with the new password:
   ```bash
   # Update the .env file (replace NEW_PASSWORD with the password from previous step)
   sudo sed -i "s/ACR_PASSWORD=.*/ACR_PASSWORD=NEW_PASSWORD/" /home/<username>/azure-docker-playground/docker-challenges/.env
   ```
5. **[VM]** Ensure the user can authenticate with Docker:
   ```bash
   # Source the .env file to get the variables
   source /home/<username>/azure-docker-playground/docker-challenges/.env
   
   # Test login as the user
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
# [VM] Check for security updates
sudo apt update && apt list --upgradable

# [VM] Check for exposed ports
sudo netstat -tulpn | grep LISTEN

# [VM] Check Docker security
docker info --format '{{json .SecurityOptions}}'
```

## Backup and Recovery
### Regular Backup Strategy
1. **VM Snapshots**:
   ```bash
   # [LOCAL] Create a VM snapshot
   az vm snapshot create \
     --resource-group $RESOURCE_GROUP \
     --name $GUI_VM_NAME-backup-$(date +%Y%m%d) \
     --vm-name $GUI_VM_NAME
   ```
2. **Configuration Backup**:
   ```bash
   # [VM] Backup important configuration files
   sudo tar -czf /tmp/adp-config-backup-$(date +%Y%m%d).tar.gz \
     /etc/ssh/sshd_config \
     /etc/xrdp/xrdp.ini \
     /home/azureadmin/azure-docker-playground/.env \
     /home/azureadmin/azure-docker-playground/ansible \
     /home/azureadmin/azure-docker-playground/scripts
   ```
   ```bash
   # [LOCAL] Download the backup
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
   # [LOCAL] Restore VM from snapshot
   az vm restore --resource-group $RESOURCE_GROUP \
     --name $GUI_VM_NAME \
     --restore-from-snapshot-id /subscriptions/<subscription-id>/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Compute/snapshots/$GUI_VM_NAME-backup-<date>
   ```
2. **Configuration Restoration**:
   ```bash
   # [LOCAL] Upload and extract backup
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
- **Email Support**: Contact the maintainers at <support@example.com>
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
# [VM] Create a version file after each major update
echo "Azure Docker Playground v1.0.0 - $(date)" > /home/azureadmin/azure-docker-playground/VERSION
