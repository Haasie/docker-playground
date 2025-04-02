# Azure Docker Playground - User Guide

Welcome to the Azure Docker Playground! This environment allows you to learn and practice Docker concepts in a safe, isolated environment with a graphical user interface.

## Table of Contents

- [Getting Started](#getting-started)
- [Connecting to the Environment](#connecting-to-the-environment)
- [Docker Challenges](#docker-challenges)
- [Earning Badges](#earning-badges)
- [Tips and Tricks](#tips-and-tricks)
- [Troubleshooting](#troubleshooting)

## Getting Started

The Azure Docker Playground provides a complete environment for learning Docker with:

- Ubuntu Desktop with GUI access via RDP
- Pre-installed tools (Docker, Docker Compose, VS Code, Firefox)
- Three progressive challenges to test your Docker skills
- A badge system to track your achievements

## Connecting to the Environment

To access the Docker Playground environment:

1. Log in to the [Azure Portal](https://portal.azure.com)
2. Navigate to the Virtual Machines section
3. Select the Docker Playground VM (typically named `adp-dev-gui-vm`)
4. Click on "Connect" and select "Bastion"
5. Enter the username and password provided by your administrator
6. You will be connected to the Ubuntu desktop environment

### Prerequisites

- Access credentials provided by your administrator
- RDP client (built into Windows, Microsoft Remote Desktop for macOS/iOS)

### Connection Steps

1. **Access Azure Bastion**:
   - Open the URL provided by your administrator in your web browser
   - This will take you to the Azure Bastion connection page

2. **Enter Credentials**:
   - Username: Provided by your administrator
   - Authentication Type: SSH Private Key
   - SSH Private Key: Upload the private key file provided by your administrator

3. **Connect to the Desktop**:
   - Once connected, you'll see the Ubuntu Desktop interface
   - Use the desktop shortcuts to access Terminal, VS Code, and Firefox

## Docker Challenges

The playground includes three progressive challenges to help you learn Docker:

### Challenge 1: Hello Container

**Objective**: Start an Nginx web server in a Docker container and expose it on port 8080.

**Location**: `~/azure-docker-playground/docker-challenges/hello-container/`

**Steps**:
1. Navigate to the challenge directory
2. Build the Docker image using the provided Dockerfile
3. Run a container from the image, exposing port 8080
4. Validate your solution with the validation script

### Challenge 2: Compose Master

**Objective**: Deploy a WordPress and MySQL stack using Docker Compose.

**Location**: `~/azure-docker-playground/docker-challenges/compose-master/`

**Steps**:
1. Navigate to the challenge directory
2. Review the docker-compose.yml file
3. Start the services using Docker Compose
4. Verify WordPress is accessible on port 80
5. Validate your solution with the validation script

### Challenge 3: Image Architect

**Objective**: Build a custom Docker image and push it to Azure Container Registry (ACR).

**Location**: `~/azure-docker-playground/docker-challenges/custom-image/`

**Steps**:
1. Navigate to the challenge directory
2. Review the Dockerfile and application code
3. Build and push the image using the provided script
4. Validate your solution with the validation script

## Earning Badges

Each challenge awards a badge upon successful completion:

- **Challenge 1**: "Container Novice" badge
- **Challenge 2**: "Orchestrator" badge
- **Challenge 3**: "ACR Pro" badge

### Tracking Your Progress

The Docker Playground includes a command-line tool called `challenge-cli` to help you track your progress through the challenges. This tool allows you to view available challenges, check which ones you've completed, and validate your solutions.

```bash
# List all available challenges
challenge-cli list-challenges

# View your earned badges (completed challenges)
challenge-cli list-badges

# Validate a specific challenge
challenge-cli validate hello-container
```

When you run `challenge-cli list-badges`, you'll see a list of all challenges with checkmarks (✅) for completed ones and X marks (❌) for incomplete ones, along with your overall progress.

## Tips and Tricks

### Docker Commands

**Basic Docker Commands**:
```bash
# List running containers
docker ps

# List all containers (including stopped)
docker ps -a

# List images
docker images

# Pull an image
docker pull <image-name>

# Build an image
docker build -t <image-name> .

# Run a container
docker run -d -p <host-port>:<container-port> <image-name>

# View container logs
docker logs <container-id>

# Stop a container
docker stop <container-id>

# Remove a container
docker rm <container-id>
```

**Docker Compose Commands**:
```bash
# Start services
docker-compose up -d

# View running services
docker-compose ps

# View service logs
docker-compose logs

# Stop services
docker-compose down
```

### Using VS Code

VS Code is pre-installed with Docker extensions. Use it to:

- Edit Dockerfiles and docker-compose.yml files with syntax highlighting
- View and manage containers and images with the Docker extension
- Edit code with full IDE features

### Using Desktop Shortcuts

Your desktop environment is pre-configured with shortcuts for common tools:

*   **ADP Terminal**: Opens a terminal window directly in the `~/azure-docker-playground` directory.
*   **Firefox**: Launches the Firefox web browser.
*   **VS Code**: Opens the Visual Studio Code editor.
*   **USER_GUIDE.md**: A copy of this guide for easy reference.

**Important**: The first time you try to double-click a `.desktop` shortcut (like ADP Terminal, Firefox, or VS Code), you might need to mark it as trusted. Right-click the icon and look for an option like "Allow Launching" or "Trust and Launch". This only needs to be done once per shortcut.

## Resetting the Environment

If you need to reset the Docker Playground to its initial state (for example, to allow a new user to start fresh):

### For Users

To reset just your Docker resources and challenge progress:

1. Open a terminal in the VM
2. Run the following commands:

```bash
# Stop and remove all containers
docker stop $(docker ps -a -q) 2>/dev/null || true
docker rm $(docker ps -a -q) 2>/dev/null || true

# Remove all custom images
docker rmi $(docker images -a -q) 2>/dev/null || true

# Remove all volumes
docker volume rm $(docker volume ls -q) 2>/dev/null || true

# Clean up Docker system
docker system prune -a -f

# Reset challenge directories
rm -rf ~/azure-docker-playground/docker-challenges/* 2>/dev/null || true
rm -rf ~/.docker-playground-progress 2>/dev/null || true
rm -rf ~/completed-challenges 2>/dev/null || true

# Reset badge progress if it exists
if [ -f ~/.docker-badges.json ]; then
    echo '{}' > ~/.docker-badges.json
fi
```

### For Administrators

#### Environment Reset

Administrators can perform a complete environment reset using the provided script:

1. Connect to the deployment environment where you ran the initial setup
2. Run the reset script:

```bash
./scripts/reset-environment.sh
```

This script offers two reset options:

- **Quick Reset**: Cleans Docker resources on the VM
- **Full Reset**: Redeploys the VM from its original image

#### User Management

Administrators can create additional user accounts for participants without sharing the `azureadmin` credentials:

1. SSH into the VM via Azure Bastion as `azureadmin`
2. Run the user creation script:

```bash
# Interactive mode (will prompt for username and password)
sudo ~/azure-docker-playground/scripts/create-user.sh

# Or non-interactive mode
sudo ~/azure-docker-playground/scripts/create-user.sh username password
```

This will:

- Create a new user account with the specified credentials
- Set up their environment with all necessary permissions and shortcuts
- Allow them to log in directly via Azure Bastion using their own credentials

The reset script will guide you through the process and provide options for resetting the Azure Container Registry as well.

## Troubleshooting

### Common Issues

1. **Docker Permission Issues**:
   ```bash
   # Add your user to the docker group (if needed)
   sudo usermod -aG docker $USER
   # Then log out and log back in
   ```

2. **Port Already in Use**:
   ```bash
   # Find process using a port
   sudo netstat -tuln | grep <port>
   # Kill the process
   sudo kill <process-id>
   ```

3. **Container Not Starting**:
   ```bash
   # Check container logs
   docker logs <container-id>
   ```

4. **ACR Login Issues**:
   ```bash
   # Login to ACR
   az acr login --name <acr-name>
   ```

### Getting Help

If you encounter issues not covered in this guide, please contact your administrator for assistance.
