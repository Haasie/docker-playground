#!/bin/bash

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}===== Azure Docker Playground - Create User =====${NC}\n"

# Check if running as root/sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run this script with sudo or as root${NC}"
  exit 1
fi

# Get username and password
if [ $# -lt 1 ]; then
    read -p "Enter username for new user: " USERNAME
else
    USERNAME=$1
fi

if [ $# -lt 2 ]; then
    read -s -p "Enter password for $USERNAME: " PASSWORD
    echo
    read -s -p "Confirm password: " PASSWORD_CONFIRM
    echo
    
    if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
        echo -e "${RED}Passwords do not match. Exiting.${NC}"
        exit 1
    fi
else
    PASSWORD=$2
fi

# Check if user already exists
if id "$USERNAME" &>/dev/null; then
    echo -e "${YELLOW}User $USERNAME already exists.${NC}"
    read -p "Do you want to reset their password? (y/n): " RESET
    if [[ $RESET == "y" || $RESET == "Y" ]]; then
        echo "$USERNAME:$PASSWORD" | chpasswd
        echo -e "${GREEN}Password for $USERNAME has been reset.${NC}"
    else
        echo -e "${YELLOW}No changes made to user $USERNAME.${NC}"
    fi
    exit 0
fi

# Create the user
echo -e "${BLUE}Creating user $USERNAME...${NC}"
useradd -m -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd

# Add user to necessary groups
echo -e "${BLUE}Adding $USERNAME to necessary groups...${NC}"
usermod -aG sudo $USERNAME
usermod -aG docker $USERNAME
usermod -aG ssl-cert $USERNAME

# Create Desktop directory if it doesn't exist
echo -e "${BLUE}Setting up Desktop for $USERNAME...${NC}"
DESKTOP_DIR="/home/$USERNAME/Desktop"
mkdir -p $DESKTOP_DIR
chown $USERNAME:$USERNAME $DESKTOP_DIR
chmod 755 $DESKTOP_DIR

# Copy the challenges to the user's directory
echo -e "${BLUE}Setting up Docker challenges for $USERNAME...${NC}"
ADMIN_CHALLENGES_DIR="/home/azureadmin/azure-docker-playground/docker-challenges"
USER_ADP_DIR="/home/$USERNAME/azure-docker-playground"
USER_CHALLENGES_DIR="$USER_ADP_DIR/docker-challenges"

# Create the user's azure-docker-playground directory
mkdir -p $USER_ADP_DIR
chown $USERNAME:$USERNAME $USER_ADP_DIR

# Create and copy challenges to the user's directory
mkdir -p $USER_CHALLENGES_DIR
cp -r $ADMIN_CHALLENGES_DIR/* $USER_CHALLENGES_DIR/
chown -R $USERNAME:$USERNAME $USER_CHALLENGES_DIR

# Copy Desktop shortcuts
echo -e "${BLUE}Creating Desktop shortcuts for $USERNAME...${NC}"
cp /home/azureadmin/Desktop/*.desktop $DESKTOP_DIR/
chown $USERNAME:$USERNAME $DESKTOP_DIR/*.desktop
chmod 755 $DESKTOP_DIR/*.desktop

# Copy USER_GUIDE.md to Desktop
cp /home/azureadmin/Desktop/USER_GUIDE.md $DESKTOP_DIR/
chown $USERNAME:$USERNAME $DESKTOP_DIR/USER_GUIDE.md
chmod 644 $DESKTOP_DIR/USER_GUIDE.md

# Update the Challenges.desktop file to point to the user's directory
sed -i "s|/home/azureadmin/|/home/$USERNAME/|g" $DESKTOP_DIR/Challenges.desktop
sed -i "s|/home/azureadmin/|/home/$USERNAME/|g" $DESKTOP_DIR/ADP_Terminal.desktop

# Set up LXDE configuration for the new user
echo -e "${BLUE}Setting up LXDE desktop environment for $USERNAME...${NC}"
LXDE_CONFIG_DIR="/home/$USERNAME/.config/lxsession/LXDE"
mkdir -p $LXDE_CONFIG_DIR
chown -R $USERNAME:$USERNAME "/home/$USERNAME/.config"

# Copy LXDE configuration from admin user if it exists, or create a new one
if [ -f "/home/azureadmin/.config/lxsession/LXDE/desktop.conf" ]; then
    cp "/home/azureadmin/.config/lxsession/LXDE/desktop.conf" "$LXDE_CONFIG_DIR/"
else
    # Create default LXDE configuration
    cat > "$LXDE_CONFIG_DIR/desktop.conf" << EOF
[Session]
window_manager=openbox
[GTK]
sNet/ThemeName=Clearlooks
sNet/IconThemeName=nuoveXT2
EOF
fi

# Set proper ownership and permissions
chown $USERNAME:$USERNAME "$LXDE_CONFIG_DIR/desktop.conf"
chmod 644 "$LXDE_CONFIG_DIR/desktop.conf"

# Ensure LXDE is the default session for this user
echo -e "${BLUE}Setting LXDE as default session for $USERNAME...${NC}"
echo "[Desktop]\nSession=LXDE" > "/home/$USERNAME/.dmrc"
chown $USERNAME:$USERNAME "/home/$USERNAME/.dmrc"
chmod 644 "/home/$USERNAME/.dmrc"

echo -e "\n${GREEN}User $USERNAME has been created successfully!${NC}"
echo -e "${BLUE}They can now log in via Azure Bastion with these credentials:${NC}"
echo -e "  Username: ${YELLOW}$USERNAME${NC}"
echo -e "  Password: ${YELLOW}(as provided)${NC}"
echo -e "\n${BLUE}The user has access to:${NC}"
echo -e "  - Docker challenges via the Desktop shortcut"
echo -e "  - Sudo privileges for system administration"
echo -e "  - Docker group for running containers without sudo"
