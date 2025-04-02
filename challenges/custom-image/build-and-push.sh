#!/bin/bash

# Load environment variables
if [ -f "../.env" ]; then
    source "../.env"
fi

# Check if ACR_LOGIN_SERVER is set
if [ -z "$ACR_LOGIN_SERVER" ]; then
    echo "Error: ACR_LOGIN_SERVER environment variable is not set."
    echo "Make sure you have the .env file with the correct ACR information."
    exit 1
fi

# Check if USERNAME is set
if [ -z "$USERNAME" ]; then
    # Try to get the current username
    USERNAME=$(whoami)
fi

echo "Building and pushing custom image to Azure Container Registry..."
echo "ACR: $ACR_LOGIN_SERVER"
echo "Username: $USERNAME"

# Image name and tag
IMAGE_NAME="custom-app"
IMAGE_TAG="latest"
FULL_IMAGE_NAME="$ACR_LOGIN_SERVER/$IMAGE_NAME:$IMAGE_TAG"

# Build the image with username as build arg
echo "\nBuilding image: $FULL_IMAGE_NAME"
docker build --build-arg USERNAME="$USERNAME" -t "$FULL_IMAGE_NAME" .

# Check if build was successful
if [ $? -ne 0 ]; then
    echo "\nError: Docker build failed."
    exit 1
fi

echo "\nImage built successfully!"

# Get ACR admin credentials
echo "\nGetting ACR admin credentials for: $ACR_NAME"

# Check if ACR_NAME is set
if [ -z "$ACR_NAME" ]; then
    echo "Error: ACR_NAME environment variable is not set."
    echo "Make sure you have the .env file with the correct ACR information."
    exit 1
fi

# Get admin credentials from environment or prompt user
if [ -z "$ACR_USERNAME" ] || [ -z "$ACR_PASSWORD" ]; then
    echo "ACR admin credentials not found in environment variables."
    echo "Using Docker login with admin credentials..."
    read -p "Enter ACR admin username: " ACR_USERNAME
    read -s -p "Enter ACR admin password: " ACR_PASSWORD
    echo
fi

# Log in to ACR using Docker
echo "\nLogging in to ACR: $ACR_LOGIN_SERVER"
echo "$ACR_PASSWORD" | docker login "$ACR_LOGIN_SERVER" -u "$ACR_USERNAME" --password-stdin

# Check if login was successful
if [ $? -ne 0 ]; then
    echo "\nError: Failed to log in to ACR."
    echo "Make sure you have provided the correct admin credentials."
    exit 1
fi

# Push the image to ACR
echo "\nPushing image to ACR: $FULL_IMAGE_NAME"
docker push "$FULL_IMAGE_NAME"

# Check if push was successful
if [ $? -ne 0 ]; then
    echo "\nError: Failed to push image to ACR."
    exit 1
fi

echo "\nImage successfully pushed to ACR!"
echo "Image: $FULL_IMAGE_NAME"

# Write the image info to a file for validation
echo "$FULL_IMAGE_NAME" > .image_info

echo "\nRun ./validate.sh to verify and claim your badge."
