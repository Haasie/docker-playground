#!/bin/bash

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}===== Removing Public IP from VM (Secure Configuration) =====${NC}\n"

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

# Get the NIC name for the VM
echo -e "\n${BLUE}Getting VM network interface...${NC}"
VM_NIC_ID=$(az vm show -g $RESOURCE_GROUP -n $GUI_VM_NAME --query "networkProfile.networkInterfaces[0].id" -o tsv)
VM_NIC_NAME=$(echo $VM_NIC_ID | cut -d'/' -f9)

if [ -z "$VM_NIC_NAME" ]; then
    echo -e "\n${RED}Error: Could not determine VM network interface name.${NC}"
    exit 1
fi

echo -e "VM NIC Name: ${GREEN}$VM_NIC_NAME${NC}"

# Get the public IP resource ID
echo -e "\n${BLUE}Getting public IP resource ID...${NC}"
PUBLIC_IP_ID=$(az network nic show --resource-group $RESOURCE_GROUP --name $VM_NIC_NAME --query "ipConfigurations[0].publicIPAddress.id" -o tsv)

if [ -z "$PUBLIC_IP_ID" ]; then
    echo -e "\n${YELLOW}No public IP found associated with the VM. It's already secure.${NC}"
    exit 0
fi

PUBLIC_IP_NAME=$(echo $PUBLIC_IP_ID | cut -d'/' -f9)
echo -e "Public IP Name: ${GREEN}$PUBLIC_IP_NAME${NC}"

# Create a temporary NIC configuration file
echo -e "\n${BLUE}Creating temporary NIC configuration...${NC}"
az network nic show --resource-group $RESOURCE_GROUP --name $VM_NIC_NAME > nic-config.json

# Modify the configuration to remove the public IP
echo -e "\n${BLUE}Modifying NIC configuration to remove public IP...${NC}"
jq '.ipConfigurations[0].publicIPAddress = null' nic-config.json > nic-config-updated.json

# Update the NIC with the new configuration
echo -e "\n${BLUE}Updating NIC configuration...${NC}"
az network nic update --resource-group $RESOURCE_GROUP --name $VM_NIC_NAME --set ipConfigurations[0].publicIpAddress=null

# Check if the update was successful
if [ $? -ne 0 ]; then
    echo -e "\n${RED}Error: Failed to update NIC configuration.${NC}"
    echo -e "Trying alternative method..."
    
    # Alternative method: Recreate the IP configuration
    SUBNET_ID=$(az network nic show --resource-group $RESOURCE_GROUP --name $VM_NIC_NAME --query "ipConfigurations[0].subnet.id" -o tsv)
    PRIVATE_IP=$(az network nic show --resource-group $RESOURCE_GROUP --name $VM_NIC_NAME --query "ipConfigurations[0].privateIPAddress" -o tsv)
    
    az network nic ip-config update \
      --resource-group $RESOURCE_GROUP \
      --nic-name $VM_NIC_NAME \
      --name ipconfig1 \
      --subnet $SUBNET_ID \
      --private-ip-address $PRIVATE_IP \
      --public-ip-address ""
    
    if [ $? -ne 0 ]; then
        echo -e "\n${RED}Error: Both methods failed to remove the public IP.${NC}"
        echo -e "Please remove the public IP manually through the Azure Portal."
        exit 1
    fi
fi

# Delete the public IP resource
echo -e "\n${BLUE}Deleting public IP resource...${NC}"
az network public-ip delete \
  --resource-group $RESOURCE_GROUP \
  --name "$PUBLIC_IP_NAME"

if [ $? -ne 0 ]; then
    echo -e "\n${YELLOW}Warning: Failed to delete public IP resource. It may still be attached to another resource.${NC}"
    echo -e "You may need to delete it manually through the Azure Portal."
fi

# Clean up temporary files
rm -f nic-config.json nic-config-updated.json

echo -e "\n${BLUE}=======================================${NC}"
echo -e "${GREEN}Public IP removal completed!${NC}"
echo -e "\n${BLUE}Your VM is now more secure with no direct access from the internet.${NC}"
echo -e "You can still access your VM using Azure Bastion through the Azure Portal."
echo -e "\n${BLUE}To access your VM:${NC}"
echo -e "1. Go to the Azure Portal"
echo -e "2. Navigate to your VM ($GUI_VM_NAME)"
echo -e "3. Click 'Connect' and select 'Bastion'"
echo -e "4. Enter your credentials and connect"
echo -e "\n${BLUE}=======================================${NC}"
