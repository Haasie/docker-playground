#!/bin/bash

echo "Validating Compose Master Challenge..."

# Allow some time for services to initialize
echo "Waiting a few seconds for WordPress to initialize..."
sleep 10

# Check if WordPress is running on port 80 (Retry a few times)
max_retries=3
retry_delay=5
response="000"
for (( i=1; i<=max_retries; i++ )); do
    echo "Attempt $i/$max_retries: Checking WordPress on http://localhost:80..."
    response=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://localhost:80)
    if [ "$response" == "200" ]; then
        echo "WordPress responded successfully."
        break
    fi
    echo "WordPress not ready yet, waiting $retry_delay seconds..."
    sleep $retry_delay
done

# Check if Docker Compose services are running
# Use project name likely derived from the directory "compose-master"
project_name="compose-master"
wp_container_name="${project_name}-wordpress-1"
wp_running=$(docker ps --filter "name=${wp_container_name}" --format '{{.Names}}' | grep -c "${wp_container_name}")

db_container_name="${project_name}-db-1"
db_running=$(docker ps --filter "name=${db_container_name}" --format '{{.Names}}' | grep -c "${db_container_name}")


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
        echo "- WordPress did not respond with HTTP 200 on port 80 (Status: $response)"
    fi

    if [ "$wp_running" -eq 0 ]; then
        echo "- WordPress container ('${wp_container_name}') is not running or not named as expected."
    fi

    if [ "$db_running" -eq 0 ]; then
        echo "- MySQL container ('${db_container_name}') is not running or not named as expected."
    fi

    echo -e "\nMake sure you:"
    echo "1. Ran 'docker compose up -d' in the 'compose-master' directory"
    echo "2. Both '${wp_container_name}' and '${db_container_name}' containers are running (check 'docker ps')"
    echo "3. WordPress is fully initialized and accessible (check 'curl -I http://localhost:80')"
    echo "4. Check container logs ('docker compose logs') for errors."

    echo -e "\nTry running these commands:"
    echo "docker compose logs wordpress"
    echo "docker compose logs db"
    echo "docker ps"
    echo "curl -I http://localhost:80"
    exit 1
fi
