#!/bin/bash

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}===== Setting up Azure Docker Playground Environment =====\033[0m\n"

# Install prerequisites
echo -e "${BLUE}Installing prerequisites...\033[0m"
sudo apt update
sudo apt install -y git ansible

# Clone repository
echo -e "\n${BLUE}Cloning repository...\033[0m"
git clone https://github.com/Haasie/docker-playground.git ~/azure-docker-playground
cd ~/azure-docker-playground

# Set up environment
echo -e "\n${BLUE}Setting up environment...\033[0m"
export USER=$(whoami)

# Install Docker and tools
echo -e "\n${BLUE}Installing Docker and tools...\033[0m"
ansible-playbook -i localhost, -c local ansible/docker.yml

# Set up GUI environment
echo -e "\n${BLUE}Setting up GUI environment...\033[0m"
ansible-playbook -i localhost, -c local ansible/gui-setup.yml

# Set up Docker challenges
echo -e "\n${BLUE}Setting up Docker challenges...\033[0m"
./scripts/setup-challenges.sh adpdevacr adpdevacr.azurecr.io

echo -e "\n${GREEN}Setup completed successfully!\033[0m"
echo -e "${BLUE}You can now access the Docker Playground environment.\033[0m"

# Clear bash history for security
echo -e "\n${BLUE}Clearing bash history for security...\033[0m"
cat /dev/null > ~/.bash_history && history -c
