# Azure Docker Playground - Administrator Guide

This guide provides comprehensive instructions for administrators to deploy, manage, and maintain the Azure Docker Playground environment. It addresses common issues and follows security best practices for production deployments.

## Table of Contents

- [Getting Started](#getting-started)
  - [Obtaining the Project](#obtaining-the-project)
  - [Repository Structure](#repository-structure)
- [Prerequisites](#prerequisites)
- [Deployment](#deployment)
  - [Deployment Parameters](#deployment-parameters)
- [Post-Deployment Configuration](#post-deployment-configuration)
  - [Access the VM Securely](#access-the-vm-securely)
  - [Configure the VM Environment (via Generated Script)](#configure-the-vm-environment-via-generated-script)
- [Troubleshooting](#troubleshooting)
  - [Common Issues](#common-issues)
  - [Logs and Diagnostics](#logs-and-diagnostics)
- [Security Considerations](#security-considerations)
- [Backup and Monitoring](#backup-and-monitoring)
- [Maintenance](#maintenance)
  - [Utility Scripts](#utility-scripts)
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
│   ├── gui-setup.yml   # XFCE + xRDP setup
│   └── challenges.yml  # Docker challenges setup
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

The Azure Docker Playground can be deployed with a single command from the **project root directory**:

```bash
# Make the script executable (if needed)
chmod +x scripts/deploy-azure-playground.sh

# Run the deployment script from the project root
./scripts/deploy-azure-playground.sh
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

After the Azure infrastructure is deployed, some configuration steps are needed on your local machine and inside the new VM. The `post-deploy-setup.sh` script helps automate some of these tasks.

### Running the Post-Deployment Setup Script

This script, run from your **local machine's project root directory**, provides a menu to perform essential post-deployment actions:

```bash
# Make the script executable (if needed)
chmod +x scripts/post-deploy-setup.sh

# Run the post-deployment setup script from the project root
./scripts/post-deploy-setup.sh
```

The script offers the following options:

1.  **Remove public IP from VM:** Enhances security by making the VM inaccessible directly from the public internet. Access is then only possible via Azure Bastion.
2.  **Set VM password for RDP access:** Configures a password for the admin user, which is required for RDP connections through Bastion.
3.  **Generate VM connection script:** Creates a shell script (`vm-setup-YOUR_VM_NAME.sh`) containing all the commands needed to configure the environment *inside* the VM. **This generated script needs to be manually uploaded to the VM and executed there.**
4.  **Get ACR credentials and update .env file:** Retrieves the admin password for the Azure Container Registry and saves it to an `acr-credentials.env` file. This file needs to be uploaded to the VM.
5.  **Run all security enhancements:** Executes options 1 and 2 sequentially.
6.  **Exit**

It's recommended to run **Option 5** (or Options 1 and 2 individually) first to secure the VM. Then, use **Option 3** to generate the VM setup script.

### Access the VM Securely

The deployment uses Azure Bastion with the Standard SKU for secure access to the Linux VM. **After removing the public IP (Option 1 above), Bastion is the *only* way to connect.**

1. Go to the Azure Portal
2. Navigate to the deployed VM
3. Click on "Connect" and select "Bastion"
4. Enter the admin username and the password you set (using Option 2 above) or your SSH key.

> **Note**: The Standard SKU for Azure Bastion is required for proper functionality with Linux VMs, providing features like native client support and file transfer capabilities. Bastion also allows you to upload files, which is necessary for the next step.

For detailed instructions, see the [Secure Access Guide](SECURE_ACCESS_GUIDE.md).

### Configure the VM Environment (via Generated Script)

Once connected to the VM via Bastion:

1.  **Upload the generated script:** Use the Bastion file upload feature (or `scp` if using native client SSH via Bastion) to transfer the `vm-setup-YOUR_VM_NAME.sh` script (generated by Option 3 of `post-deploy-setup.sh`) to the VM's home directory (e.g., `/home/azureadmin/`).
2.  **Upload ACR credentials:** Also upload the `acr-credentials.env` file (generated by Option 4) to the VM's home directory.
3.  **Execute the script:** Make the script executable and run it:

    ```bash
    chmod +x vm-setup-YOUR_VM_NAME.sh
    ./vm-setup-YOUR_VM_NAME.sh
    ```

This script performs the necessary setup steps *inside the VM*:
*   Installs prerequisites (`git`, `ansible`).
*   Clones the `docker-playground` repository into the VM's home directory (`~/azure-docker-playground`).
*   Installs Docker using the `ansible/docker.yml` playbook.
*   Sets up the XFCE GUI environment and xRDP using the `ansible/gui-setup.yml` playbook.
*   Runs the `./scripts/setup-challenges.sh` script to configure the Docker challenges, using the ACR credentials from the uploaded `.env` file (the script expects to find `acr-credentials.env` and rename it).

After the script finishes, the VM environment is ready for users.

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

## Maintenance

### Utility Scripts

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

#### System Maintenance Scripts

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
