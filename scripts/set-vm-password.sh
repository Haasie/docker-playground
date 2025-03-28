#!/bin/bash

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}===== Setting VM Password for RDP Access =====${NC}\n"

# Load environment variables if .env file exists
if [ -f ".env" ]; then
    source .env
fi

# Check if required variables are set
if [ -z "$RESOURCE_GROUP" ] || [ -z "$GUI_VM_NAME" ]; then
    echo -e "${RED}Error: Required environment variables not set.${NC}"
    echo -e "Please ensure RESOURCE_GROUP and GUI_VM_NAME are set in your .env file."
    exit 1
fi

# Prompt for username and password
echo -e "${YELLOW}Please enter the VM username (default: azureadmin):${NC}"
read -p "> " VM_USERNAME
VM_USERNAME=${VM_USERNAME:-azureadmin}

echo -e "\n${YELLOW}Please enter a new password for $VM_USERNAME:${NC}"
read -s -p "> " VM_PASSWORD
echo ""

echo -e "\n${YELLOW}Please confirm the password:${NC}"
read -s -p "> " VM_PASSWORD_CONFIRM
echo ""

# Check if passwords match
if [ "$VM_PASSWORD" != "$VM_PASSWORD_CONFIRM" ]; then
    echo -e "\n${RED}Error: Passwords do not match.${NC}"
    exit 1
fi

# Check password complexity
if [ ${#VM_PASSWORD} -lt 12 ]; then
    echo -e "\n${RED}Error: Password must be at least 12 characters long.${NC}"
    exit 1
fi

if ! [[ $VM_PASSWORD =~ [A-Z] ]] || ! [[ $VM_PASSWORD =~ [a-z] ]] || ! [[ $VM_PASSWORD =~ [0-9] ]] || ! [[ $VM_PASSWORD =~ [\!\@\#\$\%\^\&\*\(\)\-\_\=\+] ]]; then
    echo -e "\n${RED}Error: Password must contain uppercase letters, lowercase letters, numbers, and special characters.${NC}"
    exit 1
fi

# Reset the VM password
echo -e "\n${BLUE}Resetting password for $VM_USERNAME on $GUI_VM_NAME...${NC}"
az vm user update \
  --resource-group $RESOURCE_GROUP \
  --name $GUI_VM_NAME \
  --username $VM_USERNAME \
  --password "$VM_PASSWORD"

if [ $? -ne 0 ]; then
    echo -e "\n${RED}Error: Failed to reset password.${NC}"
    exit 1
fi

echo -e "\n${GREEN}Password successfully reset for $VM_USERNAME!${NC}"
echo -e "\n${BLUE}You can now connect to your VM via Azure Bastion using:${NC}"
echo -e "  - Username: ${YELLOW}$VM_USERNAME${NC}"
echo -e "  - Password: ${YELLOW}(your new password)${NC}"

echo -e "\n${BLUE}To connect:${NC}"
echo -e "1. Go to the Azure Portal"
echo -e "2. Navigate to your VM ($GUI_VM_NAME)"
echo -e "3. Click 'Connect' and select 'Bastion'"
echo -e "4. Connection type: RDP"
echo -e "5. Enter your username and password"
echo -e "6. Click 'Connect'"

echo -e "\n${BLUE}=======================================${NC}"
