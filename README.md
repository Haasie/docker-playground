# Azure Docker Playground

A secure environment for learning and practicing Docker in Azure with a focus on security best practices and ease of deployment.

![Azure](https://img.shields.io/badge/azure-%230072C6.svg?style=for-the-badge&logo=microsoftazure&logoColor=white)
![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)
![Ansible](https://img.shields.io/badge/ansible-%231A1918.svg?style=for-the-badge&logo=ansible&logoColor=white)
![Bicep](https://img.shields.io/badge/bicep-%23000000.svg?style=for-the-badge&logo=microsoftazure&logoColor=white)

## Overview

The Azure Docker Playground provides a secure, isolated environment for learning Docker concepts with a graphical user interface. The environment is deployed entirely in Azure, with access provided through Azure Bastion for maximum security.

This project features:

- **Secure VM** with Docker and Docker Compose pre-installed
- **Azure Container Registry** for storing and managing container images
- **Docker Challenges** for hands-on learning and skill development
- **Secure Access** via Azure Bastion without exposing public IPs
- **GUI Environment** for visual interaction with Docker containers
- **Automated Deployment** scripts for consistent and repeatable setup

### Key Features

- **Isolated Network Environment**: Private VNet with no public IPs except for Azure Bastion
- **GUI Access**: Ubuntu Desktop with xRDP, accessible through Azure Bastion
- **Development Tools**: Docker, Docker Compose, VS Code, Firefox pre-installed
- **Private Container Registry**: Azure Container Registry with private endpoint
- **Cost Optimization**: Auto-shutdown schedule and Spot instances
- **Progressive Challenges**: Three Docker challenges with increasing difficulty
- **Gamification**: Badge system to track achievements

## Architecture

![Architecture Diagram](docs/SCREENSHOTS/architecture.png)

### Components

- **Infrastructure (Bicep)**:
  - Virtual Network with private subnet
  - Azure Bastion for secure access
  - GUI VM with Ubuntu Desktop
  - Azure Container Registry with private endpoint
  - RBAC integration with Azure AD

- **Environment Setup (Ansible)**:
  - Docker and Docker Compose installation
  - GUI setup with xRDP and development tools
  - Challenge deployment

- **Challenges**:
  - Hello Container: Basic Nginx container
  - Compose Master: WordPress/MySQL stack with Docker Compose
  - Image Architect: Custom image build and push to ACR

- **Gamification**:
  - CLI tool for badge management
  - Achievement API with Azure Table Storage backend

## Quick Start

```bash
# Clone the repository
git clone https://github.com/Haasie/docker-playground.git
cd docker-playground

# Run the automated deployment script
./scripts/deploy-azure-playground.sh

# Set up a password for RDP access via Bastion
./scripts/set-vm-password.sh
```

The deployment script will guide you through the process of setting up your Azure environment. After deployment, you can access your VM securely through Azure Bastion.

### For Administrators

See the [Administrator Guide](docs/ADMIN_GUIDE.md) for detailed instructions on:
- Deploying the environment
- Post-deployment configuration
- Maintenance and troubleshooting
- Security best practices

### For Users

See the [User Guide](docs/USER_GUIDE.md) for instructions on:
- Connecting to the environment securely
- Completing the Docker challenges
- Troubleshooting common issues

## Deployment

The environment can be deployed with a single command:

```bash
./scripts/deploy-azure-playground.sh
```

This script will:

1. Create a `.env` file with default values if it doesn't exist
2. Prompt you to edit the file with your preferences
3. Log in to Azure if needed
4. Create the resource group if it doesn't exist
5. Deploy all Azure resources using Bicep templates
6. Save all deployment outputs to the `.env` file
7. Provide clear next steps

## Security

This environment is designed with security in mind:

- **Private Network** - VMs have no public IP addresses, minimizing attack surface
- **Secure Access** - All access is provided through Azure Bastion, which provides secure, audited connections
- **Network Isolation** - Network security groups restrict traffic to only what's necessary
- **Authentication** - ACR uses admin authentication for simplicity (can be enhanced with Azure AD for production)
- **Automated Security** - Scripts to maintain security configuration and remove any accidentally exposed resources

## Troubleshooting

Common issues and their solutions:

- **RDP Connection Issues**: See the [RDP Troubleshooting Guide](docs/SECURE_ACCESS_GUIDE.md#common-rdp-issues)

- **Public IP Exposure**: Run `./scripts/fix-remove-public-ip.sh` to secure your VM

- **ACR Authentication**: Ensure ACR admin credentials are properly configured

- **Ansible Variable Issues**: Ensure the USER environment variable is set before running Ansible playbooks

For more detailed troubleshooting, see the [Admin Guide](docs/ADMIN_GUIDE.md#troubleshooting).

## Project Structure

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
├── scripts/            # Utility scripts
│   ├── deploy-azure-playground.sh  # Main deployment script
│   ├── set-vm-password.sh         # Script to set VM password for RDP
│   ├── fix-remove-public-ip.sh    # Script to remove public IPs for security
│   └── setup-challenges.sh        # Script to set up Docker challenges
└── templates/          # Configuration templates
```

## Features

- **Automated Deployment**: Single-command deployment of all Azure resources
- **Secure by Default**: No public IPs, all access through Azure Bastion
- **GUI Support**: XFCE desktop environment with RDP access via Bastion
- **Docker Challenges**: Pre-configured Docker learning exercises
- **ACR Integration**: Private container registry for storing images
- **Comprehensive Documentation**: Detailed guides for all aspects of the system

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
