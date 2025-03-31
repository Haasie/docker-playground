#!/bin/bash

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}===== Azure Docker Playground Deployment =====${NC}\n"

# Check if .env file exists, create it if not
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}Creating .env file with default values...${NC}"
    cat > .env << EOF
RESOURCE_GROUP=adp-rg
LOCATION=westeurope
ENVIRONMENT_NAME=dev
ADMIN_USERNAME=azureadmin
# Generate an SSH key if you don't have one
# ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
ADMIN_SSH_KEY="$(cat ~/.ssh/id_rsa.pub 2>/dev/null || echo "YOUR_SSH_KEY_HERE")"
EOF
    echo -e "${YELLOW}Please edit the .env file to set your SSH key and other preferences.${NC}"
    echo -e "${YELLOW}Then run this script again.${NC}"
    exit 0
fi

# Load environment variables
source .env

# Check if required variables are set
if [ -z "$RESOURCE_GROUP" ] || [ -z "$LOCATION" ] || [ -z "$ENVIRONMENT_NAME" ] || [ -z "$ADMIN_USERNAME" ] || [ -z "$ADMIN_SSH_KEY" ] || [ "$ADMIN_SSH_KEY" == "YOUR_SSH_KEY_HERE" ]; then
    echo -e "${RED}Error: Required environment variables not set.${NC}"
    echo -e "Please edit the .env file to set all required variables."
    exit 1
fi

# Login to Azure if not already logged in
echo -e "\n${BLUE}Checking Azure login status...${NC}"
az account show &> /dev/null
if [ $? -ne 0 ]; then
    echo -e "${YELLOW}Not logged in to Azure. Initiating login...${NC}"
    az login
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Failed to login to Azure.${NC}"
        exit 1
    fi
fi

# Create resource group if it doesn't exist
echo -e "\n${BLUE}Creating resource group if it doesn't exist...${NC}"
az group show --name $RESOURCE_GROUP &> /dev/null
if [ $? -ne 0 ]; then
    echo -e "Creating resource group $RESOURCE_GROUP in $LOCATION..."
    az group create --name $RESOURCE_GROUP --location $LOCATION
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Failed to create resource group.${NC}"
        exit 1
    fi
fi

# Deploy Bicep templates
echo -e "\n${BLUE}Deploying Azure infrastructure with Bicep...${NC}"
az deployment group create \
  --resource-group $RESOURCE_GROUP \
  --template-file bicep/main.bicep \
  --parameters \
    location=$LOCATION \
    environmentName=$ENVIRONMENT_NAME \
    adminUsername=$ADMIN_USERNAME \
    adminSshKey="$ADMIN_SSH_KEY"

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to deploy Bicep templates.${NC}"
    exit 1
fi

# Get deployment outputs
echo -e "\n${BLUE}Getting deployment outputs...${NC}"
ACR_NAME=$(az deployment group show --resource-group $RESOURCE_GROUP --name main --query properties.outputs.acrName.value -o tsv)
ACR_LOGIN_SERVER=$(az acr show --name $ACR_NAME --resource-group $RESOURCE_GROUP --query loginServer -o tsv)
GUI_VM_NAME=$(az deployment group show --resource-group $RESOURCE_GROUP --name main --query properties.outputs.guiVmName.value -o tsv)
ACR_PASSWORD=$(az acr credential show --name $ACR_NAME --query "passwords[0].value" -o tsv)

# Save outputs to .env file
echo -e "\n${BLUE}Saving deployment outputs to .env file...${NC}"
grep -v "^ACR_NAME=\|^ACR_LOGIN_SERVER=\|^GUI_VM_NAME=\|^ACR_PASSWORD=" .env > .env.tmp
echo "ACR_NAME=$ACR_NAME" >> .env.tmp
echo "ACR_LOGIN_SERVER=$ACR_LOGIN_SERVER" >> .env.tmp
echo "GUI_VM_NAME=$GUI_VM_NAME" >> .env.tmp
echo "ACR_PASSWORD=$ACR_PASSWORD" >> .env.tmp
mv .env.tmp .env

echo -e "\n${BLUE}=======================================${NC}"
echo -e "${GREEN}Azure infrastructure deployed successfully!${NC}"
echo -e "\n${BLUE}Resource Group:${NC} $RESOURCE_GROUP"
echo -e "${BLUE}VM Name:${NC} $GUI_VM_NAME"
echo -e "${BLUE}ACR Name:${NC} $ACR_NAME"
echo -e "${BLUE}ACR Login Server:${NC} $ACR_LOGIN_SERVER"

echo -e "\n${BLUE}Next Steps:${NC}"

echo -e "1. Run the post-deployment setup script from the project root directory for automated configuration tasks like removing the public IP, setting the VM password, and generating the VM setup script:"
echo -e "   ${YELLOW}./scripts/post-deploy-setup.sh${NC}"

echo -e "\n2. Use the menu in 'post-deploy-setup.sh' to:
   - Run security enhancements (remove public IP, set password).
   - Generate the VM setup script ('vm-setup-*.sh').
   - Get ACR credentials ('acr-credentials.env')."

echo -e "\n3. Connect to your VM via Azure Bastion using the password you set:
   - Go to the Azure Portal -> VM ($GUI_VM_NAME) -> Connect -> Bastion."

echo -e "\n4. Upload the generated 'vm-setup-*.sh' and 'acr-credentials.env' files to the VM using Bastion file transfer."

echo -e "\n5. Execute the setup script *inside the VM* to install Docker, GUI, and challenges:
   ${YELLOW}chmod +x vm-setup-*.sh${NC}
   ${YELLOW}./vm-setup-*.sh${NC}"

echo -e "\n${BLUE}Maintenance Commands:${NC}"
echo -e "- Reset environment for new users:   ${YELLOW}./scripts/reset-environment.sh${NC}"
echo -e "- Remove all Azure resources:      ${YELLOW}./scripts/destroy-env.sh $RESOURCE_GROUP${NC}"

echo -e "\n${BLUE}For detailed instructions, see the Admin Guide:${NC}"
echo -e "${YELLOW}docs/ADMIN_GUIDE.md${NC}"
echo -e "${BLUE}For secure access instructions:${NC}"
echo -e "${YELLOW}docs/SECURE_ACCESS_GUIDE.md${NC}"
echo -e "\n${BLUE}=======================================${NC}"
