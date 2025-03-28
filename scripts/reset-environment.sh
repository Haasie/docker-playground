#!/bin/bash

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}===== Resetting Azure Docker Playground Environment =====${NC}\n"

# Load environment variables if .env file exists
if [ -f ".env" ]; then
    source .env
fi

# Check if required variables are set
if [ -z "$RESOURCE_GROUP" ] || [ -z "$GUI_VM_NAME" ] || [ -z "$ACR_NAME" ]; then
    echo -e "${RED}Error: Required environment variables not set.${NC}"
    echo -e "Please ensure RESOURCE_GROUP, GUI_VM_NAME, and ACR_NAME are set in your .env file."
    exit 1
fi

echo -e "${YELLOW}This script will reset the Docker Playground environment to its initial state.${NC}"
echo -e "${YELLOW}All user progress, challenge completions, and custom Docker images will be removed.${NC}"
echo -e "\n${BLUE}Do you want to continue? (y/n)${NC}"
read -p "> " CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo -e "\n${YELLOW}Reset operation cancelled.${NC}"
    exit 0
fi

# Option to reset via VM restart or full redeployment
echo -e "\n${BLUE}Reset options:${NC}"
echo -e "1. Quick Reset (Clean Docker resources only)"
echo -e "2. Full Reset (Redeploy VM from image)"
read -p "> " RESET_OPTION

case $RESET_OPTION in
    1)
        echo -e "\n${BLUE}Performing Quick Reset...${NC}"
        
        # Create a reset script to run on the VM
        cat > vm-reset-commands.sh << 'EOF'
#!/bin/bash

# Stop and remove all containers
echo "Stopping and removing all Docker containers..."
docker stop $(docker ps -a -q) 2>/dev/null || true
docker rm $(docker ps -a -q) 2>/dev/null || true

# Remove all images except for base images
echo "Removing all Docker images..."
docker rmi $(docker images -a -q) 2>/dev/null || true

# Remove all volumes
echo "Removing all Docker volumes..."
docker volume rm $(docker volume ls -q) 2>/dev/null || true

# Remove all networks except default ones
echo "Removing all custom Docker networks..."
docker network rm $(docker network ls -q -f "type=custom") 2>/dev/null || true

# Clean up Docker system
echo "Cleaning up Docker system..."
docker system prune -a -f

# Reset challenge directories
echo "Resetting challenge directories..."
rm -rf ~/docker-challenges/* 2>/dev/null || true

# Reset user home directory artifacts
rm -rf ~/.docker-playground-progress 2>/dev/null || true
rm -rf ~/completed-challenges 2>/dev/null || true

# Reset badge progress if it exists
if [ -f ~/.docker-badges.json ]; then
    echo "Resetting badge progress..."
    echo '{}' > ~/.docker-badges.json
fi

echo "Environment reset complete!"
EOF

        chmod +x vm-reset-commands.sh
        
        echo -e "\n${BLUE}Connecting to VM to run reset commands...${NC}"
        echo -e "${YELLOW}Note: You'll need to manually copy and run these commands if using Bastion.${NC}"
        echo -e "${YELLOW}The reset script has been saved as 'vm-reset-commands.sh'${NC}"
        
        # Check if VM has a public IP
        VM_PUBLIC_IP=$(az vm show -g $RESOURCE_GROUP -n $GUI_VM_NAME -d --query publicIps -o tsv)
        
        if [ -n "$VM_PUBLIC_IP" ]; then
            echo -e "\n${BLUE}VM has a public IP. You can use SSH to run the reset script:${NC}"
            echo -e "${YELLOW}scp vm-reset-commands.sh $ADMIN_USERNAME@$VM_PUBLIC_IP:~/${NC}"
            echo -e "${YELLOW}ssh $ADMIN_USERNAME@$VM_PUBLIC_IP 'bash vm-reset-commands.sh'${NC}"
        else
            echo -e "\n${BLUE}VM has no public IP. Connect via Azure Bastion and run these commands:${NC}"
            echo -e "${YELLOW}1. Go to Azure Portal > Virtual Machines > $GUI_VM_NAME > Connect > Bastion${NC}"
            echo -e "${YELLOW}2. Copy the content of vm-reset-commands.sh${NC}"
            echo -e "${YELLOW}3. Paste and run the commands in the Bastion session${NC}"
        fi
        ;;
        
    2)
        echo -e "\n${BLUE}Performing Full Reset (VM Redeployment)...${NC}"
        
        # Get the VM's image reference
        echo -e "\n${BLUE}Getting VM image reference...${NC}"
        VM_IMAGE=$(az vm show -g $RESOURCE_GROUP -n $GUI_VM_NAME --query "storageProfile.imageReference.id" -o tsv)
        
        if [ -z "$VM_IMAGE" ]; then
            # If no custom image, get the marketplace image
            VM_IMAGE_PUBLISHER=$(az vm show -g $RESOURCE_GROUP -n $GUI_VM_NAME --query "storageProfile.imageReference.publisher" -o tsv)
            VM_IMAGE_OFFER=$(az vm show -g $RESOURCE_GROUP -n $GUI_VM_NAME --query "storageProfile.imageReference.offer" -o tsv)
            VM_IMAGE_SKU=$(az vm show -g $RESOURCE_GROUP -n $GUI_VM_NAME --query "storageProfile.imageReference.sku" -o tsv)
            VM_IMAGE_VERSION=$(az vm show -g $RESOURCE_GROUP -n $GUI_VM_NAME --query "storageProfile.imageReference.version" -o tsv)
            
            echo -e "VM uses marketplace image: ${GREEN}$VM_IMAGE_PUBLISHER:$VM_IMAGE_OFFER:$VM_IMAGE_SKU:$VM_IMAGE_VERSION${NC}"
        else
            echo -e "VM uses custom image: ${GREEN}$VM_IMAGE${NC}"
        fi
        
        # Get VM size
        VM_SIZE=$(az vm show -g $RESOURCE_GROUP -n $GUI_VM_NAME --query "hardwareProfile.vmSize" -o tsv)
        echo -e "VM size: ${GREEN}$VM_SIZE${NC}"
        
        # Get VM admin username and SSH key
        ADMIN_USERNAME=$(az vm show -g $RESOURCE_GROUP -n $GUI_VM_NAME --query "osProfile.adminUsername" -o tsv)
        SSH_KEY=$(az vm show -g $RESOURCE_GROUP -n $GUI_VM_NAME --query "osProfile.linuxConfiguration.ssh.publicKeys[0].keyData" -o tsv)
        
        echo -e "Admin username: ${GREEN}$ADMIN_USERNAME${NC}"
        
        # Get VM network interface
        VM_NIC_ID=$(az vm show -g $RESOURCE_GROUP -n $GUI_VM_NAME --query "networkProfile.networkInterfaces[0].id" -o tsv)
        
        # Stop and deallocate the VM
        echo -e "\n${BLUE}Stopping and deallocating the VM...${NC}"
        az vm deallocate -g $RESOURCE_GROUP -n $GUI_VM_NAME
        
        # Delete the VM but keep the disks and NICs
        echo -e "\n${BLUE}Deleting the VM (keeping disks and NICs)...${NC}"
        az vm delete -g $RESOURCE_GROUP -n $GUI_VM_NAME --yes
        
        # Recreate the VM with the same configuration
        echo -e "\n${BLUE}Recreating the VM with the same configuration...${NC}"
        
        CREATE_CMD="az vm create -g $RESOURCE_GROUP -n $GUI_VM_NAME --size $VM_SIZE \
          --nics $VM_NIC_ID \
          --admin-username $ADMIN_USERNAME \
          --ssh-key-values \"$SSH_KEY\""
        
        if [ -z "$VM_IMAGE" ]; then
            # Use marketplace image
            CREATE_CMD="$CREATE_CMD \
              --image $VM_IMAGE_PUBLISHER:$VM_IMAGE_OFFER:$VM_IMAGE_SKU:$VM_IMAGE_VERSION"
        else
            # Use custom image
            CREATE_CMD="$CREATE_CMD \
              --image $VM_IMAGE"
        fi
        
        # Execute the create command
        eval $CREATE_CMD
        
        if [ $? -ne 0 ]; then
            echo -e "\n${RED}Error: Failed to recreate the VM.${NC}"
            exit 1
        fi
        
        echo -e "\n${GREEN}VM successfully recreated!${NC}"
        echo -e "${YELLOW}Note: You'll need to run the setup scripts again to configure the environment.${NC}"
        ;;
        
    *)
        echo -e "\n${RED}Invalid option. Reset operation cancelled.${NC}"
        exit 1
        ;;
esac

# Reset ACR repositories (optional)
echo -e "\n${BLUE}Do you want to reset the Azure Container Registry repositories? (y/n)${NC}"
read -p "> " RESET_ACR

if [[ "$RESET_ACR" =~ ^[Yy]$ ]]; then
    echo -e "\n${BLUE}Resetting ACR repositories...${NC}"
    
    # Get list of repositories
    REPOS=$(az acr repository list --name $ACR_NAME -o tsv)
    
    if [ -z "$REPOS" ]; then
        echo -e "${YELLOW}No repositories found in ACR.${NC}"
    else
        for REPO in $REPOS; do
            echo -e "Deleting repository: ${YELLOW}$REPO${NC}"
            az acr repository delete --name $ACR_NAME --repository $REPO --yes
        done
        echo -e "${GREEN}All repositories deleted from ACR.${NC}"
    fi
fi

echo -e "\n${BLUE}=======================================${NC}"
echo -e "${GREEN}Environment reset completed!${NC}"
echo -e "\n${BLUE}The environment is now ready for the next user.${NC}"
echo -e "${BLUE}=======================================${NC}"
