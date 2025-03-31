#!/bin/bash

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}===== Azure Docker Playground Post-Deployment Setup =====${NC}\n"

# Check if deployment info exists
if [ ! -f "../deployment-info.txt" ] && [ ! -f "./deployment-info.txt" ]; then
    echo -e "${YELLOW}Deployment info file not found. Please provide the following information:${NC}"
    read -p "Resource Group Name: " RESOURCE_GROUP
    read -p "VM Name: " GUI_VM_NAME
    read -p "ACR Name: " ACR_NAME
    read -p "ACR Login Server: " ACR_LOGIN_SERVER
else
    # Load deployment information
    DEPLOYMENT_INFO_FILE=$([ -f "../deployment-info.txt" ] && echo "../deployment-info.txt" || echo "./deployment-info.txt")
    source $DEPLOYMENT_INFO_FILE
    echo -e "${GREEN}Loaded deployment information from $DEPLOYMENT_INFO_FILE${NC}"
fi

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check for required tools
echo -e "\n${BLUE}Checking for required tools...${NC}"
MISSING_TOOLS=0

if ! command_exists az; then
    echo -e "${YELLOW}Azure CLI not found. Installing...${NC}"
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to install Azure CLI. Please install it manually.${NC}"
        MISSING_TOOLS=1
    fi
fi

# Check Azure login
echo -e "\n${BLUE}Checking Azure login...${NC}"
az account show &>/dev/null
if [ $? -ne 0 ]; then
    echo -e "${YELLOW}Not logged in to Azure. Initiating login...${NC}"
    az login
    if [ $? -ne 0 ]; then
        echo -e "${RED}Azure login failed. Please login manually with 'az login' and try again.${NC}"
        exit 1
    fi
fi

# Menu of post-deployment tasks
echo -e "\n${BLUE}Post-Deployment Configuration Menu${NC}"
echo -e "1. Remove public IP from VM (Enhanced Security)"
echo -e "2. Set VM password for RDP access"
echo -e "3. Generate VM connection script"
echo -e "4. Get ACR credentials and update .env file"
echo -e "5. Run all security enhancements (1-2)"
echo -e "6. Exit"

read -p "Select an option (1-6): " OPTION

case $OPTION in
    1)
        echo -e "\n${BLUE}Removing public IP from VM...${NC}"
        scripts/fix-remove-public-ip.sh $RESOURCE_GROUP $GUI_VM_NAME
        ;;
    2)
        echo -e "\n${BLUE}Setting VM password...${NC}"
        scripts/set-vm-password.sh $RESOURCE_GROUP $GUI_VM_NAME
        ;;
    3)
        echo -e "\n${BLUE}Generating VM connection script...${NC}"
        
        # Create a script to set up the VM environment
        VM_SETUP_SCRIPT="vm-setup-$GUI_VM_NAME.sh"
        cat > $VM_SETUP_SCRIPT << EOF
#!/bin/bash

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "\${BLUE}===== Setting up Azure Docker Playground Environment =====${NC}\n"

# Install prerequisites
echo -e "\${BLUE}Installing prerequisites...${NC}"
sudo apt update
sudo apt install -y git ansible

# Clone repository
echo -e "\n\${BLUE}Cloning repository...${NC}"
git clone https://github.com/Haasie/docker-playground.git ~/azure-docker-playground
cd ~/azure-docker-playground

# Set up environment
echo -e "\n\${BLUE}Setting up environment...${NC}"
export USER=\$(whoami)

# Install Docker and tools
echo -e "\n\${BLUE}Installing Docker and tools...${NC}"
ansible-playbook -i localhost, -c local ansible/docker.yml

# Set up GUI environment
echo -e "\n\${BLUE}Setting up GUI environment...${NC}"
ansible-playbook -i localhost, -c local ansible/gui-setup.yml

# Set up Docker challenges
echo -e "\n\${BLUE}Setting up Docker challenges...${NC}"
./scripts/setup-challenges.sh $ACR_NAME $ACR_LOGIN_SERVER

echo -e "\n\${GREEN}Setup completed successfully!${NC}"
echo -e "\${BLUE}You can now access the Docker Playground environment.${NC}"
EOF

        chmod +x $VM_SETUP_SCRIPT
        echo -e "${GREEN}VM setup script created: $VM_SETUP_SCRIPT${NC}"
        echo -e "${YELLOW}Upload this script to your VM and run it to complete the setup.${NC}"
        echo -e "${YELLOW}You can use Azure Bastion file transfer feature to upload the script.${NC}"
        ;;
    4)
        echo -e "\n${BLUE}Getting ACR credentials...${NC}"
        
        # Get ACR password
        echo -e "${YELLOW}Retrieving ACR admin password...${NC}"
        ACR_PASSWORD=$(az acr credential show --name $ACR_NAME --query "passwords[0].value" -o tsv)
        
        if [ -z "$ACR_PASSWORD" ]; then
            echo -e "${RED}Failed to retrieve ACR password. Please check if ACR exists and you have proper permissions.${NC}"
        else
            echo -e "${GREEN}ACR password retrieved successfully.${NC}"
            
            # Create .env file for Docker challenges
            ENV_FILE="acr-credentials.env"
            cat > $ENV_FILE << EOF
ACR_NAME=$ACR_NAME
ACR_LOGIN_SERVER=$ACR_LOGIN_SERVER
ACR_USERNAME=$ACR_NAME
ACR_PASSWORD=$ACR_PASSWORD
EOF
            
            echo -e "${GREEN}ACR credentials saved to $ENV_FILE${NC}"
            echo -e "${YELLOW}Upload this file to your VM and rename it to .env in the docker-challenges directory.${NC}"
        fi
        ;;
    5)
        echo -e "\n${BLUE}Running all security enhancements...${NC}"
        
        echo -e "\n${BLUE}1. Removing public IP from VM...${NC}"
        scripts/fix-remove-public-ip.sh $RESOURCE_GROUP $GUI_VM_NAME
        
        echo -e "\n${BLUE}2. Setting VM password...${NC}"
        scripts/set-vm-password.sh $RESOURCE_GROUP $GUI_VM_NAME
        
        echo -e "\n${GREEN}All security enhancements completed.${NC}"
        ;;
    6)
        echo -e "\n${BLUE}Exiting post-deployment setup.${NC}"
        exit 0
        ;;
    *)
        echo -e "\n${RED}Invalid option. Exiting.${NC}"
        exit 1
        ;;
esac

echo -e "\n${BLUE}Post-deployment setup completed.${NC}"
echo -e "${YELLOW}For detailed instructions, see the Admin Guide: docs/ADMIN_GUIDE.md${NC}"
