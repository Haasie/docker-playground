#!/bin/bash

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}===== Setting up Docker Challenges =====${NC}\n"

# Ensure USER environment variable is set
export USER=$(whoami)

# Check if ACR_NAME and ACR_LOGIN_SERVER are provided as arguments
if [ $# -eq 2 ]; then
    ACR_NAME=$1
    ACR_LOGIN_SERVER=$2
    echo -e "Using provided ACR information:\n- ACR Name: ${GREEN}$ACR_NAME${NC}\n- ACR Login Server: ${GREEN}$ACR_LOGIN_SERVER${NC}"
else
    # Prompt for ACR information
    echo -e "${YELLOW}Please enter your Azure Container Registry information:${NC}"
    read -p "ACR Name: " ACR_NAME
    read -p "ACR Login Server (e.g., acrname.azurecr.io): " ACR_LOGIN_SERVER
    
    if [ -z "$ACR_NAME" ] || [ -z "$ACR_LOGIN_SERVER" ]; then
        echo -e "\n${RED}Error: ACR Name and Login Server are required.${NC}"
        exit 1
    fi
fi

# Run the Ansible playbook
echo -e "\n${BLUE}Running Ansible playbook to set up challenges...${NC}"
ansible-playbook -i localhost, -c local ansible/challenges.yml -e "acr_name=$ACR_NAME acr_login_server=$ACR_LOGIN_SERVER"

# Check if playbook execution was successful
if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}Docker Challenges setup completed successfully!${NC}"
    echo -e "\n${YELLOW}Next steps:${NC}"
    echo -e "1. Configure the ACR admin password as described in the Admin Guide"
    echo -e "2. Test the ACR login with the credentials"
else
    echo -e "\n${RED}Error: Failed to set up Docker Challenges.${NC}"
    exit 1
fi
