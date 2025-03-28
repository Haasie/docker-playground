# Azure Docker Playground - Administrator Guide

This guide provides comprehensive instructions for administrators to deploy, manage, and maintain the Azure Docker Playground environment. It addresses common issues and follows security best practices for production deployments.

## Table of Contents

- [Getting Started](#getting-started)
  - [Obtaining the Project](#obtaining-the-project)
  - [Repository Structure](#repository-structure)
- [Prerequisites](#prerequisites)
- [Deployment](#deployment)
- [Post-Deployment Configuration](#post-deployment-configuration)
  - [Access the VM Securely](#access-the-vm-securely)
  - [Set Up Docker Challenges](#set-up-docker-challenges)
  - [Configure ACR Admin Password](#configure-acr-admin-password)
- [Troubleshooting](#troubleshooting)
  - [Common Issues](#common-issues)
  - [Logs and Diagnostics](#logs-and-diagnostics)
- [Security Considerations](#security-considerations)
- [Maintenance](#maintenance-tasks)
  - [Available Scripts](#available-scripts)
  - [Resetting the Environment](#resetting-the-environment)
  - [Removing the Environment](#removing-the-environment)

## Getting Started

### Obtaining the Project

To get started with the Azure Docker Playground, you first need to clone the repository:

```bash
# Clone the repository
git clone https://github.com/Haasie/docker-playground.git

# Navigate to the project directory
cd docker-playground
```

Alternatively, you can download the project as a ZIP file from GitHub:

1. Go to [https://github.com/Haasie/docker-playground](https://github.com/Haasie/docker-playground)
2. Click the 'Code' button
3. Select 'Download ZIP'
4. Extract the ZIP file to your local machine

### Repository Structure

The repository is organized as follows:

```bash
├── ansible/            # Ansible playbooks for VM configuration
│   ├── docker.yml      # Docker installation
│   └── gui-setup.yml   # XFCE + xRDP setup
├── bicep/              # Bicep templates for Azure infrastructure
│   ├── main.bicep      # Main deployment template
│   ├── network.bicep   # VNet/Subnet/Bastion
│   ├── gui-vm.bicep    # Ubuntu VM
│   └── acr.bicep       # Container Registry
├── challenges/         # Docker learning challenges
├── docs/               # Documentation
│   ├── ADMIN_GUIDE.md  # For infrastructure admins
│   ├── SECURE_ACCESS_GUIDE.md # Secure access instructions
│   └── USER_GUIDE.md   # For developers
├── gamification/       # Badge and achievement system
├── scripts/            # Utility scripts
│   ├── deploy-azure-playground.sh  # Main deployment script
│   ├── destroy-env.sh             # Remove all Azure resources
│   ├── fix-remove-public-ip.sh    # Script to remove public IPs for security
│   ├── reset-environment.sh       # Reset environment for new users
│   ├── set-vm-password.sh         # Script to set VM password for RDP
│   └── setup-challenges.sh        # Script to set up Docker challenges
└── templates/          # Configuration templates
```

The `scripts/` directory contains all the utility scripts needed for deployment, management, and maintenance of the Azure Docker Playground environment. Each script is designed to handle a specific aspect of the environment lifecycle.

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
chmod +x deploy-azure-playground.sh

# Run the deployment script
./deploy-azure-playground.sh
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

### Access the VM Securely

The deployment uses Azure Bastion with the Standard SKU for secure access to the Linux VM:

1. Go to the Azure Portal
2. Navigate to the deployed VM
3. Click on "Connect" and select "Bastion"
4. Enter the admin username and SSH key or password

> **Note**: The Standard SKU for Azure Bastion is required for proper functionality with Linux VMs, providing features like native client support and file transfer capabilities.

For detailed instructions, see the [Secure Access Guide](SECURE_ACCESS_GUIDE.md).

### Set Up Docker Challenges

After deploying the infrastructure, set up the Docker challenges using the provided script:

```bash
# Navigate to the scripts directory
cd scripts

# Make the script executable (if needed)
chmod +x setup-challenges.sh

# Run the setup script with your ACR details
./setup-challenges.sh <acr-name> <acr-login-server>
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

## Maintenance Tasks

### Available Scripts

The Azure Docker Playground includes several utility scripts to help with deployment, configuration, and maintenance. All scripts are located in the `scripts/` directory.

#### Deployment Scripts

**`deploy-azure-playground.sh`**

- **Purpose**: Main deployment script that creates the entire Azure Docker Playground environment
- **Parameters**:
  - Resource Group Name (optional, default: adp-rg)
  - Location (optional, default: westeurope)
  - Environment Name (optional, default: dev)
- **Usage**:

  ```bash
  cd scripts
  chmod +x deploy-azure-playground.sh
  ./deploy-azure-playground.sh
  ```

- **What it does**:
  - Creates Azure resource group if it doesn't exist
  - Deploys Bicep templates for VNet, Subnet, Bastion, VM, and ACR
  - Sets up networking with private endpoints
  - Configures security settings

**`setup-challenges.sh`**

- **Purpose**: Sets up Docker challenges in the Azure Container Registry
- **Parameters**:
  - ACR Name (required)
  - ACR Login Server (required)
- **Usage**:

  ```bash
  cd scripts
  chmod +x setup-challenges.sh
  ./setup-challenges.sh myacr myacr.azurecr.io
  ```

- **What it does**:
  - Builds Docker challenge images
  - Pushes images to the specified ACR
  - Sets up challenge configurations

#### Maintenance Scripts

**`set-vm-password.sh`**

- **Purpose**: Sets or resets the password for VM RDP access
- **Parameters**:
  - Resource Group (required)
  - VM Name (required)
  - New Password (will be prompted securely)
- **Usage**:

  ```bash
  cd scripts
  chmod +x set-vm-password.sh
  ./set-vm-password.sh adp-rg adp-vm-dev
  ```

**`fix-remove-public-ip.sh`**

- **Purpose**: Removes public IP addresses from VMs for enhanced security
- **Parameters**:
  - Resource Group (required)
  - VM Name (required)
- **Usage**:

  ```bash
  cd scripts
  chmod +x fix-remove-public-ip.sh
  ./fix-remove-public-ip.sh adp-rg adp-vm-dev
  ```

- **Security Note**: This script implements the security best practice of keeping VMs on a private network and using Azure Bastion for access.

**`reset-environment.sh`**

- **Purpose**: Resets the Docker Playground environment for new users
- **Options**:
  - Quick Reset: Cleans Docker resources without redeploying (default)
  - Full Reset: Redeploys the VM from its original image
- **Usage**:

  ```bash
  cd scripts
  chmod +x reset-environment.sh
  ./reset-environment.sh [--quick|--full]
  ```

- **What it does**:
  - Removes all Docker containers, images, and volumes
  - Resets the ACR repositories (optional)
  - For full reset: redeploys the VM

**`destroy-env.sh`**

- **Purpose**: Completely removes all Azure Docker Playground resources
- **Parameters**:
  - Resource Group (required)
- **Usage**:

  ```bash
  cd scripts
  chmod +x destroy-env.sh
  ./destroy-env.sh adp-rg
  ```

- **Warning**: This script permanently deletes all resources. Use with caution.

### Resetting the Environment

To reset the Docker Playground to its initial state for a new user:

```bash
# Navigate to the scripts directory
cd scripts

# Make the script executable (if needed)
chmod +x reset-environment.sh

# Run the reset script
./reset-environment.sh
```

The script offers two reset options:

- **Quick Reset**: Cleans Docker resources on the VM without redeploying
- **Full Reset**: Redeploys the VM from its original image

It also provides an option to reset the Azure Container Registry repositories.

### Removing the Environment

To completely remove the Azure Docker Playground environment:

```bash
# Navigate to the scripts directory
cd scripts

# Make the script executable (if needed)
chmod +x destroy-env.sh

# Run the cleanup script
./destroy-env.sh
```

The script will:
1. Prompt for confirmation
2. Delete the resource group and all resources within it
3. Clean up local deployment information
