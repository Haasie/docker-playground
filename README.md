# Azure Docker Playground

A complete Azure-based Docker learning environment with GUI access via browser, three progressive challenges, and a gamification system.

## Overview

The Azure Docker Playground provides a secure, isolated environment for learning Docker concepts with a graphical user interface. The environment is deployed entirely in Azure, with access provided through Azure Bastion.

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

## Getting Started

### For Administrators

See the [Administrator Guide](docs/ADMIN_GUIDE.md) for detailed instructions on:
- Deploying the environment
- Post-deployment configuration
- Maintenance and troubleshooting
- Cleanup procedures

### For Users

See the [User Guide](docs/USER_GUIDE.md) for instructions on:
- Connecting to the environment
- Completing the Docker challenges
- Earning badges
- Troubleshooting common issues

## Deployment

The environment can be deployed with a single command:

```bash
./scripts/deploy.sh
```

This script will:
1. Check for dependencies and install them if needed
2. Prompt for deployment parameters
3. Deploy the complete infrastructure
4. Provide instructions for post-deployment configuration

## Cleanup

To remove the environment and all associated resources:

```bash
./scripts/destroy-env.sh
```

## Directory Structure

```
/bicep/               # Bicep infrastructure templates
  main.bicep          # Main template
  network.bicep       # VNet/Bastion
  gui-vm.bicep        # Ubuntu Desktop VM
  acr.bicep           # Private ACR
/ansible/             # Ansible playbooks
  docker.yml          # Docker installation
  gui-setup.yml       # xRDP + tools
  challenges.yml      # Deploy challenges
/gamification/        # Gamification components
  challenge-cli/      # CLI tool (Python)
  achievement-api/    # Flask + Dockerfile
/scripts/             # Deployment scripts
  deploy.sh           # One-command deploy
  destroy-env.sh      # Complete cleanup
/docs/                # Documentation
  ADMIN_GUIDE.md      # For infrastructure admins
  USER_GUIDE.md       # For developers
  SCREENSHOTS/        # GUI workflow visuals
/challenges/          # Challenge files
  hello-container/    # Nginx Dockerfile + validate.sh
  compose-master/     # docker-compose.yml
  custom-image/       # ACR build script
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.
