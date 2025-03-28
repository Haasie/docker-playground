# Secure VM Access Guide

This guide explains how to securely access your Azure Docker Playground VM using Azure Bastion without exposing it with a public IP address. This approach aligns with cloud security best practices and minimizes your attack surface.

## Table of Contents

- [Why Use Azure Bastion?](#why-use-azure-bastion)
- [Setting Up VM Password for RDP](#setting-up-vm-password-for-rdp)
- [Accessing Your VM via Azure Bastion](#accessing-your-vm-via-azure-bastion)
  - [SSH Access (Terminal)](#ssh-access-terminal)
  - [RDP Access (GUI)](#rdp-access-gui)
- [Setting Up the GUI Environment](#setting-up-the-gui-environment)
- [Security Best Practices](#security-best-practices)
- [Troubleshooting](#troubleshooting)
  - [Common RDP Issues](#common-rdp-issues)
  - [Fixing Public IP Issues](#fixing-public-ip-issues)

## Why Use Azure Bastion?

Azure Bastion provides secure and seamless RDP/SSH connectivity to your virtual machines directly from the Azure portal over TLS. When you use Azure Bastion:

- Your VMs don't need a public IP address, reducing the attack surface
- You don't need to worry about configuring NSG rules for RDP/SSH access
- You get protection against port scanning and other common network attacks
- All connections are logged for security auditing

## Setting Up VM Password for RDP

Before you can access your VM via RDP through Azure Bastion, you need to set up a password for your VM user. SSH keys only work for terminal/SSH connections, while RDP requires password authentication.

### Option 1: Using the Provided Script

We've created a script to simplify this process:

```bash
# Run the password setup script
./scripts/set-vm-password.sh
```

This script will:

1. Prompt you for the username (defaults to your admin username)
2. Ask for a new password (with confirmation)
3. Verify the password meets Azure's complexity requirements
4. Update the VM user's password using Azure CLI

### Option 2: Using Azure Portal

1. Go to the [Azure Portal](https://portal.azure.com)
2. Navigate to your VM resource
3. Select "Reset password" in the left menu
4. Choose "Reset password" mode
5. Enter your admin username
6. Enter and confirm a new password
7. Click "Update"

### Option 3: Using Azure CLI Directly

```bash
# Replace with your values
RESOURCE_GROUP="adp-rg"
VM_NAME="adp-dev-gui-vm"
USERNAME="azureadmin"
PASSWORD="YourComplexPassword123!"

# Reset the password
az vm user update \
  --resource-group $RESOURCE_GROUP \
  --name $VM_NAME \
  --username $USERNAME \
  --password "$PASSWORD"
```

## Accessing Your VM via Azure Bastion

### SSH Access (Terminal)

1. Go to the [Azure Portal](https://portal.azure.com)
2. Navigate to your VM resource (`adp-dev-gui-vm`)
3. Click "Connect" in the top menu
4. Select "Bastion" tab
5. For SSH access:
   - Authentication Type: SSH Private Key
   - Username: Your admin username (e.g., `azureadmin`)
   - SSH Private Key: Paste the content of your private key file
6. Click "Connect"

This will open a browser-based terminal connection to your VM.

### RDP Access (GUI)

1. Go to the [Azure Portal](https://portal.azure.com)
2. Navigate to your VM resource (`adp-dev-gui-vm`)
3. Click "Connect" in the top menu
4. Select "Bastion" tab
5. For RDP access:
   - Connection Type: Select "RDP"
   - Username: Your admin username (e.g., `azureadmin`)
   - Password: The password you set up in the previous section
6. Click "Connect"

This will open a browser-based GUI connection to your VM.

## Setting Up the GUI Environment

When you first connect via Bastion, you'll get a terminal interface. To set up a GUI environment that you can access via Bastion's HTML5 RDP client:

```bash
# Update packages
sudo apt update
sudo apt upgrade -y

# Install XFCE desktop (lighter than full Ubuntu desktop)
sudo apt install -y xfce4 xfce4-goodies

# Install and configure xRDP for internal access
sudo apt install -y xrdp
sudo systemctl enable xrdp
sudo systemctl start xrdp

# Configure xRDP to use XFCE
echo xfce4-session > ~/.xsession
sudo chmod a+x ~/.xsession

# Fix permissions
sudo usermod -a -G ssl-cert xrdp

# Restart xRDP service
sudo systemctl restart xrdp
```

After setting up the GUI environment, you can access it using the RDP Access method described above. This provides a full graphical interface through your browser, without exposing your VM to the internet.

If you're using Ansible for deployment, you can automate the GUI setup with our provided playbook:

```bash
# Set up the GUI environment using Ansible
export USER=$(whoami)  # Ensure USER environment variable is set
ansible-playbook -i localhost, -c local ansible/gui-setup.yml
```

This playbook will install and configure XFCE desktop and xRDP for you automatically.

## Security Best Practices

1. **Keep your VM on a private subnet** - Your VM should be in a subnet that doesn't have direct internet access

2. **Use Just-in-Time VM Access** - Consider enabling Just-in-Time VM access in Azure Security Center for additional security

3. **Regularly update your VM** - Keep your VM updated with the latest security patches:
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

4. **Monitor access logs** - Regularly review the Bastion access logs in Azure Monitor

5. **Use strong authentication** - Use SSH keys or strong passwords for VM access

## Troubleshooting

### Common RDP Issues

If you encounter issues with RDP access via Bastion:

1. **Check xRDP Installation and Status**:
   ```bash
   # Verify xRDP is installed
   dpkg -l | grep xrdp
   
   # Check xRDP service status
   sudo systemctl status xrdp
   
   # Restart xRDP if needed
   sudo systemctl restart xrdp
   ```

2. **Verify xRDP is Properly Configured**:
   ```bash
   # Check if xRDP is listening on port 3389
   sudo netstat -tuln | grep 3389
   
   # Check xRDP configuration
   cat /etc/xrdp/xrdp.ini
   
   # Ensure the .xsession file exists and is executable
   ls -la ~/.xsession
   echo xfce4-session > ~/.xsession
   chmod +x ~/.xsession
   ```

3. **Check for Permission Issues**:
   ```bash
   # Add xrdp user to ssl-cert group
   sudo usermod -a -G ssl-cert xrdp
   
   # Check SELinux status (if applicable)
   getenforce
   
   # Check for errors in logs
   sudo cat /var/log/xrdp-sesman.log
   sudo cat /var/log/xrdp.log
   ```

4. **Error 0x409 (Cannot connect to remote computer)**:
   This is often caused by xRDP not running or not properly configured.
   ```bash
   # Complete reinstall of xRDP
   sudo apt purge xrdp -y
   sudo apt autoremove -y
   sudo apt install xrdp -y
   sudo systemctl enable xrdp
   sudo systemctl start xrdp
   echo xfce4-session > ~/.xsession
   chmod +x ~/.xsession
   sudo usermod -a -G ssl-cert xrdp
   sudo systemctl restart xrdp
   ```

5. **Verify Desktop Environment**:
   ```bash
   # Check if XFCE is installed
   dpkg -l | grep xfce4
   
   # Install XFCE if needed
   sudo apt install -y xfce4 xfce4-goodies
   ```

### Fixing Public IP Issues

If your VM has a public IP that you want to remove for security:

```bash
# Run the fix-remove-public-ip.sh script

./scripts/fix-remove-public-ip.sh
```

This script will:

1. Get the VM's network interface details
2. Remove the public IP association from the NIC
3. Delete the public IP resource
4. Confirm the VM is now only accessible via private network

By following this guide, you'll have secure access to your VM without exposing it to the internet with a public IP address.
