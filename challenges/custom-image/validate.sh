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

echo "Validating Image Architect Challenge..."

# Check if the image info file exists
if [ ! -f ".image_info" ]; then
    echo -e "❌ Validation failed. No image information found."
    echo "Make sure you've run the build-and-push.sh script first."
    exit 1
fi

# Get the image name from the file
IMAGE_NAME=$(cat .image_info)

echo "Checking for image: $IMAGE_NAME"

# Check if the image exists in ACR
IMAGE_EXISTS=$(az acr repository show --name "$ACR_NAME" --image "${IMAGE_NAME#*/}" 2>/dev/null)

if [ -z "$IMAGE_EXISTS" ]; then
    echo -e "❌ Validation failed. Image not found in ACR."
    echo "Make sure you've successfully pushed the image to ACR using the build-and-push.sh script."
    exit 1
fi

# Get the username from the image
echo "Pulling image to check build info..."
docker pull "$IMAGE_NAME" > /dev/null 2>&1

if [ $? -ne 0 ]; then
    echo -e "❌ Validation failed. Could not pull the image from ACR."
    echo "This might be due to authentication issues. Make sure you're logged in to ACR with 'az acr login --name $ACR_NAME'."
    exit 1
fi

# Run the container to check the username
echo "Starting container to validate the image..."
CONTAINER_ID=$(docker run -d -p 5000:5000 "$IMAGE_NAME" 2>/dev/null)

if [ -z "$CONTAINER_ID" ]; then
    echo -e "❌ Validation failed. Could not start the container from the image."
    echo "Check if the image was built correctly with the proper Dockerfile."
    exit 1
fi

# Wait for container to start and be ready
echo "Waiting for container to start..."
sleep 5

# Call the API to get the username
echo "Checking container API..."
RESPONSE=$(curl -s --connect-timeout 5 http://localhost:5000/ 2>/dev/null)

if [ -z "$RESPONSE" ]; then
    echo -e "❌ Validation failed. Could not connect to the application API."
    echo "Make sure the application is running correctly on port 5000."
    docker stop "$CONTAINER_ID" > /dev/null 2>&1
    docker rm "$CONTAINER_ID" > /dev/null 2>&1
    exit 1
fi

USERNAME=$(echo $RESPONSE | grep -o '"built_by":"[^"]*"' | cut -d '"' -f 4 2>/dev/null)

# Stop and remove the container
echo "Cleaning up container..."
docker stop "$CONTAINER_ID" > /dev/null 2>&1
docker rm "$CONTAINER_ID" > /dev/null 2>&1

# Check if the username matches
if [ -z "$USERNAME" ] || [ "$USERNAME" == "unknown" ]; then
    echo -e "❌ Validation failed. Username not found in the image."
    echo "Make sure you've set the USERNAME build arg correctly when running build-and-push.sh."
    exit 1
fi

echo -e "✅ Success! Image found in ACR with username: $USERNAME"
echo "Unlocking 'ACR Pro' badge..."

# Call the challenge-cli to unlock the badge
challenge-cli unlock-badge "ACR Pro" "custom-image"

echo -e "\nCongratulations! You've earned the 'ACR Pro' badge."
echo "You've completed all the challenges!"
exit 0
