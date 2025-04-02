# Azure Docker Playground Administrator Guide

This guide provides instructions for administrators to set up, maintain, and troubleshoot the Azure Docker Playground environment.

## Initial Setup

### Prerequisites

- Azure subscription with Contributor access
- Terraform installed locally
- Azure CLI installed locally

### Deployment Steps

1. Clone the repository:
   ```bash
   git clone https://github.com/your-org/docker-playground.git
   cd docker-playground
   ```

2. Deploy the infrastructure:
   ```bash
   cd terraform
   terraform init
   terraform apply
   ```

3. Set up the environment:
   ```bash
   cd ../scripts
   ./setup-vm.sh
   ./setup-challenges.sh <acr-name> <acr-login-server>
   ```

## User Management

### Creating User Accounts

Use the `create-user.sh` script to create user accounts for participants:

```bash
./scripts/create-user.sh <username> <password>
```

This script will:
- Create a user account with the specified username and password
- Set up the user's environment with necessary files and permissions
- Create desktop shortcuts for accessing the Docker challenges
- Copy the Docker challenges to the user's directory

### Managing User Access

Users can access the VM through Azure Bastion or RDP:

1. **Azure Bastion**: Users can connect through the Azure Portal
2. **RDP**: Users can connect using an RDP client with the VM's public IP

## Maintenance Tasks

### Updating the Environment

To update the Docker Playground environment:

1. Pull the latest changes:
   ```bash
   git pull
   ```

2. Run the update script:
   ```bash
   ./scripts/update-environment.sh
   ```

### Resetting Challenges

To reset all challenges for a specific user:

```bash
sudo -u <username> ./scripts/reset-all-challenges.sh
```

### Troubleshooting Common Issues

#### X11 Display Issues

If users report problems launching graphical applications:

1. Verify the X11 display fix is applied:
   ```bash
   grep -r "fix-x11-display" /home/<username>/.bashrc
   ```

2. If missing, reapply the fix:
   ```bash
   ansible-playbook ansible/gui-setup.yml --extra-vars "current_user=<username>"
   ```

#### Docker Access Issues

If users can't access Docker:

1. Check if the user is in the docker group:
   ```bash
   groups <username> | grep docker
   ```

2. Add the user to the docker group if needed:
   ```bash
   usermod -aG docker <username>
   ```

#### ACR Authentication Issues

If users can't push to ACR:

1. Verify the .env file exists and has correct credentials:
   ```bash
   cat /home/<username>/azure-docker-playground/docker-challenges/.env
   ```

2. Update the ACR credentials if needed:
   ```bash
   ./scripts/setup-challenges.sh <acr-name> <acr-login-server>
   ```

## Security Considerations

### Sensitive Information

- The `.env` file contains ACR credentials and should be protected
- User passwords should be changed after initial login
- The `azureadmin` account should be used only for administrative tasks

### Regular Maintenance

- Apply security updates regularly:
  ```bash
  apt update && apt upgrade -y
  ```

- Review and rotate ACR credentials periodically:
  ```bash
  az acr credential renew --name <acr-name> --password-name password
  ```

## Preparing for Production

Before deploying to production:

1. Run the cleanup script to remove unnecessary files:
   ```bash
   ./cleanup.sh
   ```

2. Verify all challenges work correctly:
   ```bash
   ./scripts/verify-all-challenges.sh
   ```

3. Update documentation to reflect any changes:
   ```bash
   # Update USER_GUIDE.md and ADMIN_GUIDE.md as needed
   ```

4. Create a backup of the environment:
   ```bash
   az vm snapshot create --resource-group <resource-group> --name <snapshot-name> --vm-name <vm-name>
   ```

## Support and Feedback

For support or to provide feedback:
- Create an issue in the GitHub repository
- Contact the maintainers at support@example.com
