#!/bin/bash

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}===== Removing RDP Access from Azure Docker Playground =====${NC}\n"

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

# Remove the public IP from the VM's network interface
echo -e "\n${BLUE}Removing public IP from VM...${NC}"
az network nic ip-config update \
  --resource-group $RESOURCE_GROUP \
  --nic-name $VM_NIC_NAME \
  --name ipconfig1 \
  --public-ip-address ""

if [ $? -ne 0 ]; then
    echo -e "\n${RED}Error: Failed to remove public IP from VM.${NC}"
    exit 1
fi

# Delete the public IP resource
echo -e "\n${BLUE}Deleting public IP resource...${NC}"
az network public-ip delete \
  --resource-group $RESOURCE_GROUP \
  --name "$GUI_VM_NAME-pip"

if [ $? -ne 0 ]; then
    echo -e "\n${YELLOW}Warning: Failed to delete public IP resource. It may not exist or may still be attached to a resource.${NC}"
fi

# Get the NSG name
NSG_ID=$(az network nic show --resource-group $RESOURCE_GROUP --name $VM_NIC_NAME --query "networkSecurityGroup.id" -o tsv)
NSG_NAME=$(echo $NSG_ID | cut -d'/' -f9)

if [ -z "$NSG_NAME" ]; then
    echo -e "\n${RED}Error: Could not determine NSG name.${NC}"
    exit 1
fi

echo -e "NSG Name: ${GREEN}$NSG_NAME${NC}"

# Remove the RDP rule from the NSG
echo -e "\n${BLUE}Removing RDP rule from NSG...${NC}"
az network nsg rule delete \
  --resource-group $RESOURCE_GROUP \
  --nsg-name $NSG_NAME \
  --name AllowRDP

if [ $? -ne 0 ]; then
    echo -e "\n${YELLOW}Warning: Failed to remove RDP rule from NSG. It may not exist.${NC}"
fi

echo -e "\n${BLUE}=======================================${NC}"
echo -e "${GREEN}RDP access removal completed successfully!${NC}"
echo -e "\n${BLUE}Your VM is now more secure with no direct RDP access from the internet.${NC}"
echo -e "You can still access your VM using Azure Bastion through the Azure Portal."
echo -e "\n${BLUE}To restore RDP access in the future, run:${NC}"
echo -e "${YELLOW}./scripts/setup-rdp-access.sh${NC}"
echo -e "\n${BLUE}=======================================${NC}"
