#!/bin/bash

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}===== Setting up RDP Access for Azure Docker Playground =====${NC}\n"

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

# Create a public IP address for the VM
echo -e "\n${BLUE}Creating public IP address...${NC}"
az network public-ip create \
  --resource-group $RESOURCE_GROUP \
  --name "$GUI_VM_NAME-pip" \
  --allocation-method Static \
  --sku Standard

if [ $? -ne 0 ]; then
    echo -e "\n${RED}Error: Failed to create public IP address.${NC}"
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

# Associate the public IP with the VM's network interface
echo -e "\n${BLUE}Associating public IP with VM...${NC}"
az network nic ip-config update \
  --resource-group $RESOURCE_GROUP \
  --nic-name $VM_NIC_NAME \
  --name ipconfig1 \
  --public-ip-address "$GUI_VM_NAME-pip"

if [ $? -ne 0 ]; then
    echo -e "\n${RED}Error: Failed to associate public IP with VM.${NC}"
    exit 1
fi

# Get the public IP address
PUBLIC_IP=$(az network public-ip show \
  --resource-group $RESOURCE_GROUP \
  --name "$GUI_VM_NAME-pip" \
  --query ipAddress -o tsv)

echo -e "\n${GREEN}VM Public IP: $PUBLIC_IP${NC}"

# Get the NSG name
NSG_ID=$(az network nic show --resource-group $RESOURCE_GROUP --name $VM_NIC_NAME --query "networkSecurityGroup.id" -o tsv)
NSG_NAME=$(echo $NSG_ID | cut -d'/' -f9)

if [ -z "$NSG_NAME" ]; then
    echo -e "\n${RED}Error: Could not determine NSG name.${NC}"
    exit 1
fi

echo -e "NSG Name: ${GREEN}$NSG_NAME${NC}"

# Check if RDP rule already exists
RDP_RULE=$(az network nsg rule show --resource-group $RESOURCE_GROUP --nsg-name $NSG_NAME --name AllowRDP 2>/dev/null)

if [ -z "$RDP_RULE" ]; then
    # Add RDP rule to NSG
    echo -e "\n${BLUE}Adding RDP rule to NSG...${NC}"
    az network nsg rule create \
      --resource-group $RESOURCE_GROUP \
      --nsg-name $NSG_NAME \
      --name AllowRDP \
      --protocol tcp \
      --priority 1000 \
      --destination-port-range 3389 \
      --access allow
    
    if [ $? -ne 0 ]; then
        echo -e "\n${RED}Error: Failed to add RDP rule to NSG.${NC}"
        exit 1
    fi
else
    echo -e "\n${YELLOW}RDP rule already exists in NSG.${NC}"
fi

# Generate setup script for GUI environment
echo -e "\n${BLUE}Generating GUI setup script...${NC}"
cat > gui-setup-commands.sh << 'EOF'
#!/bin/bash

# Update packages
sudo apt update
sudo apt upgrade -y

# Install XFCE desktop (lighter than full Ubuntu desktop)
sudo apt install -y xfce4 xfce4-goodies

# Install and configure xRDP
sudo apt install -y xrdp
sudo systemctl enable xrdp
sudo systemctl start xrdp

# Configure xRDP to use XFCE
echo xfce4-session > ~/.xsession
sudo sed -i 's/port=3389/port=3389\nuse_vsock=false/' /etc/xrdp/xrdp.ini

# Fix permissions
sudo chmod a+x ~/.xsession
sudo usermod -a -G ssl-cert xrdp

# Restart xRDP service
sudo systemctl restart xrdp

# Check xRDP status
sudo systemctl status xrdp
EOF

chmod +x gui-setup-commands.sh

echo -e "\n${BLUE}=======================================${NC}"
echo -e "${GREEN}RDP access setup completed successfully!${NC}"
echo -e "\n${BLUE}Next steps:${NC}"
echo -e "1. Connect to your VM using Azure Bastion and run the GUI setup script:"
echo -e "   ${YELLOW}bash gui-setup-commands.sh${NC}"
echo -e "2. After running the script, connect to your VM using an RDP client:"
echo -e "   ${YELLOW}IP Address: $PUBLIC_IP${NC}"
echo -e "   ${YELLOW}Username: $ADMIN_USERNAME${NC}"
echo -e "\n${BLUE}Security Note:${NC}"
echo -e "Exposing RDP directly to the internet poses security risks. Consider:"
echo -e "1. Using a strong password for your VM"
echo -e "2. Limiting RDP access to your specific IP address:"
echo -e "   ${YELLOW}az network nsg rule update --resource-group $RESOURCE_GROUP --nsg-name $NSG_NAME --name AllowRDP --source-address-prefixes <your-ip>${NC}"
echo -e "3. Removing the public IP when not in use:"
echo -e "   ${YELLOW}./scripts/remove-rdp-access.sh${NC}"
echo -e "\n${BLUE}=======================================${NC}"
