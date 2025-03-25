#!/bin/bash

set -e

# Colors for output
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
NC="\033[0m" # No Color

echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}  Azure Docker Playground Deployment  ${NC}"
echo -e "${BLUE}=======================================${NC}\n"

# Check for required tools
check_dependency() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}Error: $1 is not installed.${NC}"
        if [ "$2" != "" ]; then
            echo -e "${YELLOW}$2${NC}"
        fi
        return 1
    fi
    return 0
}

install_azure_cli() {
    echo -e "\n${YELLOW}Installing Azure CLI...${NC}"
    
    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS
        brew update && brew install azure-cli
    else
        # Linux
        curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
    fi
    
    echo -e "${GREEN}Azure CLI installed successfully.${NC}"
}

install_bicep() {
    echo -e "\n${YELLOW}Installing Bicep...${NC}"
    
    az bicep install
    
    echo -e "${GREEN}Bicep installed successfully.${NC}"
}

# Check dependencies
echo -e "${BLUE}Checking dependencies...${NC}"

if ! check_dependency "az" "To install Azure CLI on macOS: 'brew update && brew install azure-cli'"; then
    read -p "Do you want to install Azure CLI now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        install_azure_cli
    else
        echo -e "${RED}Azure CLI is required for deployment. Exiting.${NC}"
        exit 1
    fi
fi

# Check if user is logged in to Azure
echo -e "\n${BLUE}Checking Azure login...${NC}"
AZ_ACCOUNT=$(az account show 2>/dev/null || echo "")

if [ -z "$AZ_ACCOUNT" ]; then
    echo -e "${YELLOW}You are not logged in to Azure. Please log in.${NC}"
    az login
fi

# Check if Bicep is installed
BICEP_VERSION=$(az bicep version 2>/dev/null || echo "")
if [ -z "$BICEP_VERSION" ]; then
    echo -e "${YELLOW}Bicep is not installed.${NC}"
    read -p "Do you want to install Bicep now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        install_bicep
    else
        echo -e "${RED}Bicep is required for deployment. Exiting.${NC}"
        exit 1
    fi
fi

# Deployment parameters
echo -e "\n${BLUE}Setting up deployment parameters...${NC}"

# Get subscription ID
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
echo -e "Using subscription: ${GREEN}$SUBSCRIPTION_ID${NC}"

# Set default values
DEFAULT_RESOURCE_GROUP="adp-rg"
DEFAULT_LOCATION="westeurope"
DEFAULT_ENV_NAME="dev"

# Prompt for parameters
read -p "Resource Group Name [$DEFAULT_RESOURCE_GROUP]: " RESOURCE_GROUP
RESOURCE_GROUP=${RESOURCE_GROUP:-$DEFAULT_RESOURCE_GROUP}

read -p "Location [$DEFAULT_LOCATION]: " LOCATION
LOCATION=${LOCATION:-$DEFAULT_LOCATION}

read -p "Environment Name [$DEFAULT_ENV_NAME]: " ENV_NAME
ENV_NAME=${ENV_NAME:-$DEFAULT_ENV_NAME}

read -p "Admin Username: " ADMIN_USERNAME
while [ -z "$ADMIN_USERNAME" ]; do
    echo -e "${RED}Admin Username cannot be empty.${NC}"
    read -p "Admin Username: " ADMIN_USERNAME
done

# Generate SSH key if not exists
SSH_KEY_PATH="$HOME/.ssh/id_rsa.pub"
if [ ! -f "$SSH_KEY_PATH" ]; then
    echo -e "\n${YELLOW}No SSH key found. Generating a new SSH key...${NC}"
    ssh-keygen -t rsa -b 4096 -f "${SSH_KEY_PATH%.*}" -N ""
fi

# Read SSH public key
ADMIN_SSH_KEY=$(cat "$SSH_KEY_PATH")

# Get Azure AD Group for Admins
echo -e "\n${BLUE}Getting Azure AD Groups...${NC}"
AD_GROUPS=$(az ad group list --query "[].{name:displayName, id:id}" -o table)
echo -e "$AD_GROUPS"

read -p "Enter the Object ID of the Admin Group: " ADMIN_GROUP_OBJECT_ID
while [ -z "$ADMIN_GROUP_OBJECT_ID" ]; do
    echo -e "${RED}Admin Group Object ID cannot be empty.${NC}"
    read -p "Enter the Object ID of the Admin Group: " ADMIN_GROUP_OBJECT_ID
done

# Create resource group if it doesn't exist
echo -e "\n${BLUE}Creating resource group if it doesn't exist...${NC}"
az group create --name "$RESOURCE_GROUP" --location "$LOCATION"

# Deploy Bicep template
echo -e "\n${BLUE}Deploying infrastructure...${NC}"
az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file "../bicep/main.bicep" \
  --parameters \
    location="$LOCATION" \
    environmentName="$ENV_NAME" \
    adminUsername="$ADMIN_USERNAME" \
    adminSshKey="$ADMIN_SSH_KEY" \
    adminGroupObjectId="$ADMIN_GROUP_OBJECT_ID"

# Get deployment outputs
echo -e "\n${BLUE}Getting deployment outputs...${NC}"
OUTPUTS=$(az deployment group show \
  --resource-group "$RESOURCE_GROUP" \
  --name "main" \
  --query "properties.outputs" -o json)

# Extract values from outputs
GUI_VM_NAME=$(echo $OUTPUTS | jq -r '.guiVmName.value')
GUI_VM_IP=$(echo $OUTPUTS | jq -r '.guiVmPrivateIp.value')
BAST_NAME=$(echo $OUTPUTS | jq -r '.bastionName.value')
ACR_NAME=$(echo $OUTPUTS | jq -r '.acrName.value')

# Save deployment info to file
echo -e "\n${BLUE}Saving deployment information...${NC}"
cat > "../deployment-info.json" << EOF
{
  "resourceGroup": "$RESOURCE_GROUP",
  "location": "$LOCATION",
  "environmentName": "$ENV_NAME",
  "adminUsername": "$ADMIN_USERNAME",
  "guiVmName": "$GUI_VM_NAME",
  "guiVmPrivateIp": "$GUI_VM_IP",
  "bastionName": "$BAST_NAME",
  "acrName": "$ACR_NAME"
}
EOF

echo -e "\n${GREEN}Deployment completed successfully!${NC}"

# Provide information about the simplified ACR configuration
echo -e "\n${GREEN}ACR Configuration Simplified${NC}"
echo -e "The Azure Container Registry has been configured with:"
echo -e "- Basic SKU with public access enabled"
echo -e "- Admin user enabled for authentication"
echo -e "- No private endpoints (to avoid permission issues)"

echo -e "\n${BLUE}Next steps:${NC}"
echo -e "1. Connect to the VM using Azure Bastion: ${YELLOW}https://portal.azure.com/#@/resource/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Compute/virtualMachines/$GUI_VM_NAME/connect${NC}"
echo -e "2. Follow the instructions in the ADMIN_GUIDE.md to set up the environment"
echo -e "3. Share the USER_GUIDE.md with your users"

echo -e "\n${BLUE}=======================================${NC}"
