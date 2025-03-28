#!/bin/bash

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}===== Cleaning up Docker Playground Repository =====${NC}\n"

# Files to remove (no longer needed)
echo -e "${YELLOW}Removing unnecessary files...${NC}"

# Remove the RDP setup/removal scripts since we're using Bastion exclusively
rm -f scripts/setup-rdp-access.sh
rm -f scripts/remove-rdp-access.sh

# Remove temporary files that might have been generated
rm -f gui-setup-commands.sh
rm -f nic-config*.json

# Remove any temporary or backup files
find . -name "*~" -delete
find . -name "*.bak" -delete
find . -name "*.tmp" -delete

# Organize documentation
echo -e "\n${YELLOW}Organizing documentation...${NC}"

# Make sure the docs directory exists
mkdir -p docs

# Move any stray documentation to the docs directory
find . -maxdepth 1 -name "*.md" ! -name "README.md" -exec mv {} docs/ \;

# Create a .gitattributes file to handle line endings consistently
echo -e "\n${YELLOW}Creating .gitattributes file for consistent line endings...${NC}"
cat > .gitattributes << 'GITATTR'
# Set default behavior to automatically normalize line endings
* text=auto

# Explicitly declare text files to be normalized
*.md text
*.sh text eol=lf
*.yml text
*.yaml text
*.json text
*.j2 text
*.py text
*.bicep text

# Declare binary files
*.png binary
*.jpg binary
*.jpeg binary
*.gif binary
*.ico binary
GITATTR

# Ensure all shell scripts are executable
echo -e "\n${YELLOW}Making all shell scripts executable...${NC}"
find ./scripts -name "*.sh" -exec chmod +x {} \;

# Create a comprehensive README if it doesn't exist
if [ ! -f README.md ] || [ $(wc -l < README.md) -lt 10 ]; then
    echo -e "\n${YELLOW}Creating comprehensive README.md...${NC}"
    cat > README.md << 'README'
# Azure Docker Playground

A secure environment for learning and practicing Docker in Azure.

## Overview

This project deploys a complete Docker learning environment in Azure, featuring:

- Secure VM with Docker and Docker Compose
- Azure Container Registry for image storage
- Docker challenges for hands-on learning
- Secure access via Azure Bastion

## Quick Start

1. Clone this repository
2. Set up environment variables in `.env`
3. Deploy Azure resources with Bicep
4. Configure the VM with Ansible playbooks

See the [Admin Guide](docs/ADMIN_GUIDE.md) for detailed instructions.

## Security

This environment is designed with security in mind:

- VMs have no public IP addresses
- Access is provided through Azure Bastion
- Network security groups restrict traffic
- ACR uses admin authentication

See the [Secure Access Guide](docs/SECURE_ACCESS_GUIDE.md) for details.

## Documentation

- [Admin Guide](docs/ADMIN_GUIDE.md): Complete deployment and management instructions
- [Secure Access Guide](docs/SECURE_ACCESS_GUIDE.md): Best practices for secure VM access

## License

MIT
README
fi

echo -e "\n${GREEN}Repository cleanup completed successfully!${NC}"
echo -e "${BLUE}=======================================${NC}"
