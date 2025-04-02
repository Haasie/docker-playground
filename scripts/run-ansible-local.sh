#!/bin/bash

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}===== Running Ansible Playbook Locally =====${NC}\n"

# Check if running as root/sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run this script with sudo or as root${NC}"
  exit 1
fi

# Get the script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ANSIBLE_DIR="$PROJECT_DIR/ansible"

# Check if the playbook exists
if [ ! -d "$ANSIBLE_DIR" ]; then
  echo -e "${RED}Error: Ansible directory not found at $ANSIBLE_DIR${NC}"
  exit 1
fi

# Create inventory file if it doesn't exist
if [ ! -f "$ANSIBLE_DIR/inventory" ]; then
  echo -e "${BLUE}Creating local inventory file...${NC}"
  echo "localhost ansible_connection=local" > "$ANSIBLE_DIR/inventory"
  echo -e "${GREEN}✓ Created inventory file${NC}"
fi

# Get the current user
CURRENT_USER=$(logname || echo $SUDO_USER || echo $(whoami))

# Run the playbook
echo -e "${BLUE}Running Ansible playbook with local inventory...${NC}"
cd "$ANSIBLE_DIR"

# Check which playbook to run
if [ "$#" -eq 0 ]; then
  echo -e "${YELLOW}No playbook specified. Available playbooks:${NC}"
  ls -1 "$ANSIBLE_DIR"/*.yml | xargs -n1 basename
  echo -e "\n${YELLOW}Usage: $0 <playbook_name> [extra_vars]${NC}"
  echo -e "Example: $0 gui-setup.yml"
  exit 1
fi

PLAYBOOK="$1"
shift

# Check if the playbook exists
if [ ! -f "$ANSIBLE_DIR/$PLAYBOOK" ]; then
  echo -e "${RED}Error: Playbook $PLAYBOOK not found in $ANSIBLE_DIR${NC}"
  exit 1
fi

# Run the playbook with the local inventory
echo -e "${BLUE}Running $PLAYBOOK with current_user=$CURRENT_USER...${NC}"
ansible-playbook -i inventory "$PLAYBOOK" --extra-vars "current_user=$CURRENT_USER" "$@"

if [ $? -eq 0 ]; then
  echo -e "\n${GREEN}Ansible playbook $PLAYBOOK completed successfully!${NC}"
else
  echo -e "\n${RED}Ansible playbook $PLAYBOOK failed. See above for errors.${NC}"
  exit 1
fi
