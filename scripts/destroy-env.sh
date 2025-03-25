#!/bin/bash

set -e

# Colors for output
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
NC="\033[0m" # No Color

echo -e "${RED}=======================================${NC}"
echo -e "${RED}  Azure Docker Playground Destruction  ${NC}"
echo -e "${RED}=======================================${NC}\n"

# Check if deployment info exists
DEPLOYMENT_INFO_FILE="../deployment-info.json"
if [ ! -f "$DEPLOYMENT_INFO_FILE" ]; then
    echo -e "${YELLOW}Deployment info file not found. Using manual input.${NC}"
    
    # Prompt for parameters
    read -p "Resource Group Name: " RESOURCE_GROUP
    while [ -z "$RESOURCE_GROUP" ]; do
        echo -e "${RED}Resource Group Name cannot be empty.${NC}"
        read -p "Resource Group Name: " RESOURCE_GROUP
    done
else
    # Load deployment info
    echo -e "${BLUE}Loading deployment information...${NC}"
    RESOURCE_GROUP=$(cat "$DEPLOYMENT_INFO_FILE" | jq -r '.resourceGroup')
    ENVIRONMENT_NAME=$(cat "$DEPLOYMENT_INFO_FILE" | jq -r '.environmentName')
    
    echo -e "Resource Group: ${GREEN}$RESOURCE_GROUP${NC}"
    echo -e "Environment: ${GREEN}$ENVIRONMENT_NAME${NC}"
fi

# Confirm deletion
echo -e "\n${RED}WARNING: This will delete all resources in the resource group '$RESOURCE_GROUP'.${NC}"
echo -e "${RED}This action cannot be undone.${NC}"
read -p "Are you sure you want to proceed? (y/n) " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "\n${YELLOW}Operation cancelled.${NC}"
    exit 0
fi

# Check if user is logged in to Azure
echo -e "\n${BLUE}Checking Azure login...${NC}"
AZ_ACCOUNT=$(az account show 2>/dev/null || echo "")

if [ -z "$AZ_ACCOUNT" ]; then
    echo -e "${YELLOW}You are not logged in to Azure. Please log in.${NC}"
    az login
fi

# Delete resource group
echo -e "\n${BLUE}Deleting resource group '$RESOURCE_GROUP'...${NC}"
echo -e "${YELLOW}This may take several minutes...${NC}"

az group delete --name "$RESOURCE_GROUP" --yes --no-wait

echo -e "\n${GREEN}Resource group deletion initiated.${NC}"
echo -e "${YELLOW}The deletion will continue in the background and may take several minutes to complete.${NC}"

# Clean up local deployment info
if [ -f "$DEPLOYMENT_INFO_FILE" ]; then
    echo -e "\n${BLUE}Cleaning up local deployment information...${NC}"
    rm "$DEPLOYMENT_INFO_FILE"
fi

echo -e "\n${GREEN}Cleanup process completed!${NC}"
echo -e "${YELLOW}Note: Resource group deletion will continue in the background.${NC}"
echo -e "You can check the status in the Azure Portal or with: ${BLUE}az group show --name \"$RESOURCE_GROUP\"${NC}"

echo -e "\n${RED}=======================================${NC}"
