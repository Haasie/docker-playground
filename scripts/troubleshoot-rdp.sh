#!/bin/bash

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}===== RDP Connection Troubleshooting Guide =====${NC}\n"

echo -e "${YELLOW}Error 0x409 indicates a 'Cannot connect to remote computer' error.${NC}\n"

echo -e "${BLUE}Step 1: Run these commands on the VM (via Azure Bastion):${NC}"
echo -e "\n1. Check if xRDP is installed:"
echo -e "   ${GREEN}dpkg -l | grep xrdp${NC}"

echo -e "\n2. Install xRDP if not present:"
echo -e "   ${GREEN}sudo apt update${NC}"
echo -e "   ${GREEN}sudo apt install -y xrdp${NC}"

echo -e "\n3. Check if xRDP service is running:"
echo -e "   ${GREEN}sudo systemctl status xrdp${NC}"

echo -e "\n4. Start and enable xRDP if not running:"
echo -e "   ${GREEN}sudo systemctl start xrdp${NC}"
echo -e "   ${GREEN}sudo systemctl enable xrdp${NC}"

echo -e "\n5. Check if port 3389 is listening:"
echo -e "   ${GREEN}sudo netstat -tuln | grep 3389${NC}"

echo -e "\n6. Configure xRDP for XFCE (recommended):"
echo -e "   ${GREEN}sudo apt install -y xfce4 xfce4-goodies${NC}"
echo -e "   ${GREEN}echo xfce4-session > ~/.xsession${NC}"
echo -e "   ${GREEN}sudo chmod a+x ~/.xsession${NC}"
echo -e "   ${GREEN}sudo sed -i 's/port=3389/port=3389\\nuse_vsock=false/' /etc/xrdp/xrdp.ini${NC}"
echo -e "   ${GREEN}sudo systemctl restart xrdp${NC}"

echo -e "\n7. Fix common permission issues:"
echo -e "   ${GREEN}sudo usermod -a -G ssl-cert xrdp${NC}"
echo -e "   ${GREEN}sudo systemctl restart xrdp${NC}"

echo -e "\n${BLUE}Step 2: Verify network connectivity:${NC}"
echo -e "\n1. Check if you can ping the VM's IP address from your local machine:"
echo -e "   ${GREEN}ping <vm-ip-address>${NC}"

echo -e "\n2. Check if port 3389 is reachable (using an online port checker):"
echo -e "   Visit https://portchecker.co and check port 3389 for your VM's IP"

echo -e "\n${BLUE}Step 3: Try alternative RDP clients:${NC}"
echo -e "\n1. If using Microsoft Remote Desktop, try FreeRDP or Remmina"
echo -e "2. If using macOS, try Microsoft Remote Desktop from the App Store"

echo -e "\n${BLUE}Step 4: Check VM boot diagnostics:${NC}"
echo -e "\n1. In Azure Portal, go to your VM"
echo -e "2. Select 'Boot diagnostics' from the left menu"
echo -e "3. Check for any error messages during boot"

echo -e "\n${BLUE}Step 5: Restart the VM:${NC}"
echo -e "\n1. Sometimes a simple restart can fix RDP issues:"
echo -e "   ${GREEN}az vm restart --resource-group adp-rg --name adp-dev-gui-vm${NC}"

echo -e "\n${BLUE}Step 6: Reset RDP configuration:${NC}"
echo -e "\n1. Connect via Bastion and run:"
echo -e "   ${GREEN}sudo apt-get purge xrdp -y${NC}"
echo -e "   ${GREEN}sudo apt-get install xrdp -y${NC}"
echo -e "   ${GREEN}sudo systemctl enable xrdp${NC}"
echo -e "   ${GREEN}sudo systemctl start xrdp${NC}"

echo -e "\n${YELLOW}If you continue to experience issues, please check the Azure documentation for more troubleshooting steps.${NC}"
