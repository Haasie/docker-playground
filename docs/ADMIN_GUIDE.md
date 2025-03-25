# Azure Docker Playground - Administrator Guide

This guide provides instructions for administrators to deploy, manage, and maintain the Azure Docker Playground environment.

## Table of Contents

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
ansible-playbook -i localhost, -c local ansible/docker.yml
ansible-playbook -i localhost, -c local ansible/gui-setup.yml
ansible-playbook -i localhost, -c local ansible/challenges.yml -e "acr_name=<acr-name> acr_login_server=<acr-login-server>"
```

Replace `<acr-name>` and `<acr-login-server>` with the values from your deployment.

### 3. Configure ACR Admin Password

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
