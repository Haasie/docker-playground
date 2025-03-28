# Azure Docker Playground - Administrator Guide

This guide provides comprehensive instructions for administrators to deploy, manage, and maintain the Azure Docker Playground environment. It addresses common issues and follows security best practices for production deployments.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Deployment](#deployment)
  - [Automated Deployment](#automated-deployment)
  - [Manual Deployment](#manual-deployment)
- [Configuration](#configuration)
  - [Access the VM Securely](#access-the-vm-securely)
  - [Configure ACR Admin Password](#configure-acr-admin-password)
  - [Verify Deployment](#verify-deployment)
- [Troubleshooting](#troubleshooting)
  - [Common Issues](#common-issues)
  - [Logs and Diagnostics](#logs-and-diagnostics)
- [Security Considerations](#security-considerations)
- [Maintenance](#maintenance)

- [Prerequisites](#prerequisites)
- [Deployment](#deployment)
- [Post-Deployment Configuration](#post-deployment-configuration)
- [Maintenance](#maintenance)
- [Troubleshooting](#troubleshooting)
- [Cleanup](#cleanup)

## Prerequisites

Before deploying the Azure Docker Playground, ensure you have the following:

1. **Azure Subscription** with appropriate permissions
2. **Azure CLI** installed (the deployment script can install it for you)
3. **SSH Key** for VM access (the deployment script can generate one if needed)
4. **Azure AD Group** for administrators

## Deployment

The Azure Docker Playground can be deployed with a single command:

```bash
# Navigate to the scripts directory
cd scripts

# Make the script executable
chmod +x deploy.sh

# Run the deployment script
./deploy.sh
```

The script will:
1. Check for dependencies and install them if needed
2. Prompt for deployment parameters
3. Create a resource group if it doesn't exist
4. Deploy the Bicep templates to create the infrastructure
5. Save deployment information for future reference

### Deployment Parameters

You will be prompted for the following parameters:

- **Resource Group Name**: The name of the Azure resource group (default: adp-rg)
- **Location**: The Azure region for deployment (default: westeurope)
- **Environment Name**: The environment name used for resource naming (default: dev)
- **Admin Username**: The username for the GUI VM
- **Admin Group Object ID**: The Object ID of the Azure AD group for administrators

## Post-Deployment Configuration

After deployment, you need to configure the environment:

### 1. Connect to the GUI VM

Use Azure Bastion to connect to the GUI VM:

1. Go to the Azure Portal
2. Navigate to the deployed VM
3. Click on "Connect" and select "Bastion"
4. Enter the admin username and SSH key or password

### 2. Run Ansible Playbooks

Once connected to the VM, run the following commands to set up the environment:

```bash
# Install Ansible
sudo apt update
sudo apt install -y ansible

# Clone the repository (if not already available)
git clone <repository-url> ~/azure-docker-playground
cd ~/azure-docker-playground

# Run the Ansible playbooks
export USER=$(whoami)  # Ensure USER environment variable is set
ansible-playbook -i localhost, -c local ansible/docker.yml
ansible-playbook -i localhost, -c local ansible/gui-setup.yml

# Set up Docker challenges using the helper script
./scripts/setup-challenges.sh <acr-name> <acr-login-server>
```

Replace `<acr-name>` and `<acr-login-server>` with the values from your deployment.

Alternatively, you can run the helper script without arguments and it will prompt you for the ACR information:

```bash
./scripts/setup-challenges.sh
```

### 3. Set Up the VM Environment

Once connected to the VM via Bastion, set up the environment:

```bash
# Install prerequisites
sudo apt update
sudo apt install -y git ansible

# Clone the repository
git clone https://github.com/Haasie/docker-playground.git ~/azure-docker-playground
cd ~/azure-docker-playground

# Set up the environment
export USER=$(whoami)  # Ensure USER environment variable is set

# Install Docker and tools
ansible-playbook -i localhost, -c local ansible/docker.yml

# Set up GUI environment
ansible-playbook -i localhost, -c local ansible/gui-setup.yml

# Set up Docker challenges
./scripts/setup-challenges.sh <acr-name> <acr-login-server>
```

Replace `<acr-name>` and `<acr-login-server>` with the values from your deployment.

Alternatively, you can run the helper script without arguments and it will prompt you for the ACR information:

```bash
./scripts/setup-challenges.sh
```

### 4. Configure ACR Admin Password

The Azure Container Registry is configured with admin access enabled. You need to retrieve the admin password and update the environment file:

1. Get the ACR admin password from the Azure Portal or using Azure CLI:

   ```bash
   # Using Azure CLI (if installed and logged in)
   ACR_PASSWORD=$(az acr credential show --name <acr-name> --query "passwords[0].value" -o tsv)
   
   # Or get it from the Azure Portal:
   # - Go to the Azure Portal
   # - Navigate to your ACR resource
   # - Go to 'Access keys' under 'Settings'
   # - Copy the password value
   ```

2. Update the .env file with the password:

   ```bash
   # Edit the .env file
   nano ~/docker-challenges/.env
   
   # Update the ACR_PASSWORD line with the password you retrieved
   # Save and exit (Ctrl+O, Enter, Ctrl+X)
   ```

3. Test the ACR login:

   ```bash
   # Test login using the credentials in the .env file
   source ~/docker-challenges/.env
   echo $ACR_PASSWORD | docker login $ACR_LOGIN_SERVER -u $ACR_USERNAME --password-stdin
   ```

### 4. Start the Achievement API

Start the achievement API container:

```bash
cd ~/azure-docker-playground/gamification/achievement-api
docker build -t achievement-api .
docker run -d -p 5050:5050 --name achievement-api achievement-api
```

## Maintenance

### Backup

To back up the environment, you should:

1. **Back up the VM**: Create a snapshot of the GUI VM disk
2. **Back up the ACR**: Export container images if needed
3. **Back up achievement data**: If using Azure Table Storage, it's automatically backed up

```bash
# Create VM snapshot
az snapshot create \
  --resource-group <resource-group> \
  --name <snapshot-name> \
  --source <vm-disk-id>
```

### Monitoring

Monitor the environment using Azure Monitor:

1. Set up alerts for VM metrics (CPU, memory)
2. Monitor ACR usage and quotas
3. Check VM auto-shutdown schedule

## Troubleshooting

### Common Issues

1. **VM Connection Issues**:
   - Verify Azure Bastion is deployed correctly
   - Check network security group rules
   - Ensure the VM is running
   - For RDP issues, see the [RDP Troubleshooting Guide](SECURE_ACCESS_GUIDE.md#troubleshooting)

2. **Package Installation Failures**:
   - If you encounter dpkg interruption errors, the Ansible playbooks include pre-tasks to fix this automatically
   - If manual intervention is needed:
     ```bash
     sudo dpkg --configure -a
     sudo apt update
     ```

3. **Docker Permission Issues**:
   - Ensure your user is in the docker group:
     ```bash
     sudo usermod -aG docker $USER
     # Log out and log back in for changes to take effect
     ```

4. **ACR Authentication Issues**:
   - Verify the ACR admin credentials:
     ```bash
     az acr login --name <acr-name> --username <acr-name> --password <acr-password>
     ```
   - If needed, regenerate the admin password:
     ```bash
     az acr credential renew --name <acr-name> --password-name password
     ```

5. **Ansible Variable Issues**:
   - Ensure the USER environment variable is set before running Ansible playbooks:
     ```bash
     export USER=$(whoami)
     ```

### Logs and Diagnostics

Check these logs for troubleshooting:

```bash
# Docker logs
sudo journalctl -u docker

# xRDP logs
sudo cat /var/log/xrdp-sesman.log

# Ansible logs (if you used -v flag)
cat ansible.log

# Azure VM boot diagnostics (via Azure Portal)
# Navigate to your VM > Boot diagnostics
```

2. **Docker Issues**:
   - Check Docker service: `sudo systemctl status docker`
   - Verify user is in the docker group: `groups`
   - Restart Docker: `sudo systemctl restart docker`

3. **ACR Access Issues**:
   - Verify private endpoint connection
   - Check RBAC permissions
   - Test ACR login: `az acr login --name <acr-name>`

## Cleanup

To completely remove the Azure Docker Playground environment:

```bash
# Navigate to the scripts directory
cd scripts

# Make the script executable
chmod +x destroy-env.sh

# Run the cleanup script
./destroy-env.sh
```

The script will:
1. Prompt for confirmation
2. Delete the resource group and all resources within it
3. Clean up local deployment information
