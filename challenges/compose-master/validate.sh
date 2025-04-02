#!/bin/bash

echo "Validating Compose Master Challenge..."

# Check if WordPress is running on port 80
response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:80)

# Check if Docker Compose services are running
# Note: Service names can vary based on directory name and compose version
wp_running=$(docker ps --format '{{.Names}}' | grep -c -E '(compose-master|docker-challenges|wordpress).*wordpress')
db_running=$(docker ps --format '{{.Names}}' | grep -c -E '(compose-master|docker-challenges|wordpress).*db')

if [ "$response" == "200" ] && [ "$wp_running" -gt 0 ] && [ "$db_running" -gt 0 ]; then
    echo "✅ Success! WordPress and MySQL are running correctly."
    echo "Unlocking 'Orchestrator' badge..."
    
    # Call the challenge-cli to unlock the badge
    challenge-cli unlock-badge "Orchestrator" "compose-master"
    
    echo -e "\nCongratulations! You've earned the 'Orchestrator' badge."
    echo "Continue to the next challenge: Image Architect"
    exit 0
else
    echo "❌ Validation failed."
    
    if [ "$response" != "200" ]; then
        echo "- WordPress is not accessible on port 80"
    fi
    
    if [ "$wp_running" -eq 0 ]; then
        echo "- WordPress container is not running"
    fi
    
    if [ "$db_running" -eq 0 ]; then
        echo "- MySQL container is not running"
    fi
    
    echo -e "\nMake sure you:"
    echo "1. Started the services using 'docker compose up' or 'docker-compose up'"
    echo "2. Both WordPress and MySQL containers are running"
    echo "3. WordPress is accessible on port 80"
    
    echo -e "\nTry running these commands:"
    echo "docker compose up -d"  # Docker Compose V2 syntax
    echo "# or if using legacy Docker Compose"
    echo "docker-compose up -d"
    echo "docker ps | grep -E 'wordpress|db'"
    echo "curl -I http://localhost:80"
    exit 1
fi
