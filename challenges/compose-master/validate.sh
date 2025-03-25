#!/bin/bash

echo "Validating Compose Master Challenge..."

# Check if WordPress is running on port 80
response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:80)

# Check if Docker Compose services are running
wp_running=$(docker ps --format '{{.Names}}' | grep -c compose-master_wordpress)
db_running=$(docker ps --format '{{.Names}}' | grep -c compose-master_db)

if [ "$response" == "200" ] && [ "$wp_running" -gt 0 ] && [ "$db_running" -gt 0 ]; then
    echo "u2705 Success! WordPress and MySQL are running correctly."
    echo "Unlocking 'Orchestrator' badge..."
    
    # Call the challenge-cli to unlock the badge
    challenge-cli unlock-badge "Orchestrator" "compose-master"
    
    echo "\nCongratulations! You've earned the 'Orchestrator' badge."
    echo "Continue to the next challenge: Image Architect"
    exit 0
else
    echo "u274c Validation failed."
    
    if [ "$response" != "200" ]; then
        echo "- WordPress is not accessible on port 80"
    fi
    
    if [ "$wp_running" -eq 0 ]; then
        echo "- WordPress container is not running"
    fi
    
    if [ "$db_running" -eq 0 ]; then
        echo "- MySQL container is not running"
    fi
    
    echo "\nMake sure you:"
    echo "1. Started the services using docker-compose up"
    echo "2. Both WordPress and MySQL containers are running"
    echo "3. WordPress is accessible on port 80"
    
    echo "\nTry running these commands:"
    echo "docker-compose up -d"
    echo "docker-compose ps"
    echo "curl http://localhost:80"
    exit 1
fi
