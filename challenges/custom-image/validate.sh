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
    echo "\u274c Validation failed. No image information found."
    echo "Make sure you've run the build-and-push.sh script first."
    exit 1
fi

# Get the image name from the file
IMAGE_NAME=$(cat .image_info)

echo "Checking for image: $IMAGE_NAME"

# Check if the image exists in ACR
IMAGE_EXISTS=$(az acr repository show --name "$ACR_NAME" --image "${IMAGE_NAME#*/}" 2>/dev/null)

if [ -z "$IMAGE_EXISTS" ]; then
    echo "\u274c Validation failed. Image not found in ACR."
    echo "Make sure you've successfully pushed the image to ACR."
    exit 1
fi

# Get the username from the image
echo "Pulling image to check build info..."
docker pull "$IMAGE_NAME" > /dev/null 2>&1

if [ $? -ne 0 ]; then
    echo "\u274c Validation failed. Could not pull the image from ACR."
    exit 1
fi

# Run the container to check the username
CONTAINER_ID=$(docker run -d -p 5000:5000 "$IMAGE_NAME")

# Wait for container to start
sleep 3

# Call the API to get the username
RESPONSE=$(curl -s http://localhost:5000/)
USERNAME=$(echo $RESPONSE | grep -o '"built_by":"[^"]*"' | cut -d '"' -f 4)

# Stop and remove the container
docker stop "$CONTAINER_ID" > /dev/null
docker rm "$CONTAINER_ID" > /dev/null

# Check if the username matches
if [ "$USERNAME" == "unknown" ]; then
    echo "\u274c Validation failed. Username not found in the image."
    echo "Make sure you've set the USERNAME build arg correctly."
    exit 1
fi

echo "\u2705 Success! Image found in ACR with username: $USERNAME"
echo "Unlocking 'ACR Pro' badge..."

# Call the challenge-cli to unlock the badge
challenge-cli unlock-badge "ACR Pro" "custom-image"

echo "\nCongratulations! You've earned the 'ACR Pro' badge."
echo "You've completed all the challenges!"
exit 0
