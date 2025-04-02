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

# --- BEGIN INTEGRATION ---

# 1. Remove Public IP Address (Logic from fix-remove-public-ip.sh)
echo -e "\n${BLUE}Removing Public IP from VM '$GUI_VM_NAME' for enhanced security...${NC}"
VM_NIC_ID=$(az vm show -g $RESOURCE_GROUP -n $GUI_VM_NAME --query "networkProfile.networkInterfaces[0].id" -o tsv 2>/dev/null)

if [ -z "$VM_NIC_ID" ]; then
    echo -e "${RED}Error: Could not determine VM network interface ID. Skipping Public IP removal.${NC}"
else
    VM_NIC_NAME=$(basename "$VM_NIC_ID") # Get NIC name from ID
    echo -e "Found NIC: ${GREEN}$VM_NIC_NAME${NC}"

    # Find the public IP associated with the NIC's primary IP Configuration (usually ipconfig1)
    PUBLIC_IP_ID=$(az network nic show -g $RESOURCE_GROUP -n $VM_NIC_NAME --query "ipConfigurations[?primary==\`true\`].publicIPAddress.id" -o tsv 2>/dev/null)

    if [ -z "$PUBLIC_IP_ID" ]; then
        echo -e "${YELLOW}No public IP found associated with the primary NIC configuration. Already secure or manually removed.${NC}"
    else
        PUBLIC_IP_NAME=$(basename "$PUBLIC_IP_ID") # Get Public IP name from ID
        IP_CONFIG_NAME=$(az network nic show -g $RESOURCE_GROUP -n $VM_NIC_NAME --query "ipConfigurations[?primary==\`true\`].name" -o tsv 2>/dev/null)
        IP_CONFIG_NAME=${IP_CONFIG_NAME:-ipconfig1} # Default to ipconfig1 if primary flag not set/found

        echo -e "Found Public IP: ${GREEN}$PUBLIC_IP_NAME${NC} on IP Config: ${GREEN}$IP_CONFIG_NAME${NC}"
        echo -e "Attempting to dissociate Public IP ($PUBLIC_IP_NAME) from NIC ($VM_NIC_NAME)..."

        # Use the update command to remove the public IP association
        az network nic ip-config update --resource-group $RESOURCE_GROUP --nic-name $VM_NIC_NAME --name $IP_CONFIG_NAME --remove publicIpAddress --output none

        if [ $? -ne 0 ]; then
            echo -e "${RED}Error: Failed to dissociate Public IP from NIC configuration '${IP_CONFIG_NAME}'.${NC}"
            echo -e "${YELLOW}Please check the Azure Portal. Manual removal might be required.${NC}"
            # Optional: Add alternative method using `az network nic update --set ipConfigurations...` if needed
        else
            echo -e "${GREEN}Successfully dissociated Public IP from NIC.${NC}"
            echo -e "Attempting to delete Public IP resource ($PUBLIC_IP_NAME)..."
            az network public-ip delete --resource-group $RESOURCE_GROUP --name "$PUBLIC_IP_NAME" --output none
            if [ $? -ne 0 ]; then
                echo -e "${YELLOW}Warning: Failed to delete Public IP resource '$PUBLIC_IP_NAME'. It might be needed for Bastion, already deleted, or have other dependencies.${NC}"
            else
                 echo -e "${GREEN}Public IP resource '$PUBLIC_IP_NAME' deleted successfully.${NC}"
            fi
        fi
    fi
fi

# 2. Set VM Password (Logic from set-vm-password.sh)
echo -e "\n${BLUE}Setting VM password for RDP access via Bastion...${NC}"
VM_USERNAME=$ADMIN_USERNAME # Use the username from .env
while true; do
    echo -e "${YELLOW}Please enter a new password for VM user '$VM_USERNAME' (required for RDP/Bastion connection):${NC}"
    read -s -p "> " VM_PASSWORD
    echo ""
    echo -e "${YELLOW}Please confirm the password:${NC}"
    read -s -p "> " VM_PASSWORD_CONFIRM
    echo ""

    if [ "$VM_PASSWORD" != "$VM_PASSWORD_CONFIRM" ]; then
        echo -e "${RED}Error: Passwords do not match. Please try again.${NC}\\n"
        continue
    fi

    # Azure password complexity requirements
    if [ ${#VM_PASSWORD} -lt 12 ] || [ ${#VM_PASSWORD} -gt 123 ] || \
       ! [[ $VM_PASSWORD =~ [A-Z] ]] || \
       ! [[ $VM_PASSWORD =~ [a-z] ]] || \
       ! [[ $VM_PASSWORD =~ [0-9] ]] || \
       ! [[ $VM_PASSWORD =~ [\\@\\#\\$\\%\\^\\&\\*\\(\\)_\\+\\=\\[\\]\\{\\}\\|\\\\:\\\'\\,\\.\\?\\/\\~\\`\\-] ]]; then
        echo -e "${RED}Error: Password must be 12-123 characters long and include uppercase, lowercase, numbers, and at least one special character. Please try again.${NC}\\n"
        continue
    fi
    break # Exit loop if passwords match and complexity is met
done

echo -e "Updating password for user '$VM_USERNAME' on VM '$GUI_VM_NAME'..."
az vm user update \
  --resource-group $RESOURCE_GROUP \
  --name $GUI_VM_NAME \
  --username $VM_USERNAME \
  --password "$VM_PASSWORD" \
  --output none

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to set VM password.${NC}"
    echo -e "${YELLOW}You may need to set it manually via the Azure Portal (VM -> Reset password).${NC}"
    # Decide if this should be a fatal error - RDP won't work without it. Let's make it fatal.
    exit 1
fi
echo -e "${GREEN}VM password set successfully for user '$VM_USERNAME'.${NC}"

# --- END INTEGRATION ---


echo -e "\n${BLUE}=======================================${NC}"
echo -e "${GREEN}Azure infrastructure deployed and initial configuration completed!${NC}"
echo -e "\n${BLUE}Resource Group:${NC} $RESOURCE_GROUP"
echo -e "${BLUE}VM Name:${NC} $GUI_VM_NAME ${YELLOW}(Public IP Removed)${NC}"
echo -e "${BLUE}Admin Username:${NC} $ADMIN_USERNAME"
echo -e "${BLUE}ACR Name:${NC} $ACR_NAME"
echo -e "${BLUE}ACR Login Server:${NC} $ACR_LOGIN_SERVER"
echo -e "${BLUE}ACR Password:${NC} (Saved in .env file)"

echo -e "\n${BLUE}Simplified 5-Step Deployment Overview:${NC}"
echo -e "1. Prerequisites & Clone Repo: ${GREEN}Done (locally)${NC}"
echo -e "2. Deploy Azure Infrastructure & Initial Config (IP Removal, Password Set): ${GREEN}Done (locally)${NC}"
echo -e "${YELLOW}---> NEXT STEPS <---${NC}"
echo -e "3. ${BLUE}Connect to VM & Transfer Files:${NC}"
echo -e "   - Connect to '$GUI_VM_NAME' via Azure Bastion (RDP) using:"
echo -e "     - Username: ${YELLOW}$ADMIN_USERNAME${NC}"
echo -e "     - Password: ${YELLOW}(the password you just set)${NC}"
echo -e "   - Upload the entire cloned 'docker-playground' project directory (containing 'ansible/', 'scripts/', '.env' etc.) to the VM's home directory (\`~/${GREEN}docker-playground${NC}\`) using Bastion's file transfer feature."
echo -e "4. ${BLUE}Configure VM Environment (Run commands ON the VM via RDP/Bastion):${NC}"
echo -e "   a. Navigate to the uploaded project directory: ${YELLOW}cd ~/docker-playground${NC}"
echo -e "   b. Make the Ansible runner script executable: ${YELLOW}chmod +x scripts/run-ansible-local.sh${NC}"
echo -e "   c. Run Ansible for Docker installation: ${YELLOW}./scripts/run-ansible-local.sh ansible/docker.yml${NC}"
echo -e "   d. Run Ansible for GUI setup: ${YELLOW}./scripts/run-ansible-local.sh ansible/gui-setup.yml${NC}"
echo -e "   e. Run Ansible for Challenges setup (passing ACR credentials from local .env):"
echo -e "      ${YELLOW}./scripts/run-ansible-local.sh ansible/challenges.yml --extra-vars \"acr_name=$ACR_NAME acr_login_server=$ACR_LOGIN_SERVER acr_password='$ACR_PASSWORD'\"${NC}"
echo -e "      ${YELLOW}(Ensure the .env file from your local machine is present in ~/docker-playground on the VM)${NC}"
echo -e "5. ${BLUE}User Management (Optional - Run ON VM):${NC}"
echo -e "   - Create dedicated user accounts: ${YELLOW}sudo ./scripts/create-user.sh${NC}"


echo -e "\n${BLUE}Maintenance Commands:${NC}"
echo -e "- Reset VM Docker environment: ${YELLOW}./scripts/reset-environment.sh quick (Run ON VM)${NC}" # Need to confirm/update script name later
echo -e "- Remove all Azure resources:  ${YELLOW}./scripts/destroy-env.sh $RESOURCE_GROUP (Run LOCALLY)${NC}" # Need to confirm/update script name later

echo -e "\n${BLUE}For detailed instructions, see the Admin Guide:${NC}"
echo -e "${YELLOW}docs/ADMIN_GUIDE.md${NC}" # This guide will need updating to reflect the new process
echo -e "\n${BLUE}=======================================${NC}"

# Note: Clearing bash history should happen within the VM setup process (e.g., end of Ansible runs or called by run-ansible-local.sh)
