#!/bin/bash

echo "Validating Hello Container Challenge..."

# Check if Nginx container is running on port 8080
response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080)

if [ "$response" == "200" ]; then
    echo "✅ Success! Nginx container is running correctly on port 8080."
    echo "Unlocking 'Container Novice' badge..."
    
    # Call the challenge-cli to unlock the badge
    challenge-cli unlock-badge "Container Novice" "hello-container"
    
    echo "\nCongratulations! You've earned the 'Container Novice' badge."
    echo "Continue to the next challenge: Compose Master"
    exit 0
else
    echo "❌ Validation failed. Nginx container is not running correctly on port 8080."
    echo "\nMake sure you:"
    echo "1. Built the Docker image using the provided Dockerfile"
    echo "2. Started a container from the image, exposing port 8080"
    echo "3. The container is currently running"
    
    echo "\nTry running these commands:"
    echo "docker build -t hello-nginx ."
    echo "docker run -d -p 8080:80 hello-nginx"
    echo "curl http://localhost:8080"
    exit 1
fi
