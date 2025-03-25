# Challenge 2: Compose Master

## Objective
Deploy a WordPress and MySQL stack using Docker Compose.

## Requirements
- Use the provided docker-compose.yml file
- Start the WordPress and MySQL containers
- Verify WordPress is accessible on port 80

## Steps

1. **Review the docker-compose.yml file**
   Take a moment to understand the services defined in the compose file:
   - WordPress container connected to a MySQL database
   - Persistent volumes for both services
   - Environment variables for database connection

2. **Start the containers**
   ```bash
   docker-compose up -d
   ```

3. **Check the status of your containers**
   ```bash
   docker-compose ps
   ```

4. **Verify WordPress is running**
   Open a browser and navigate to: http://localhost:80
   
   You should see the WordPress setup page.

5. **Validate your solution**
   ```bash
   ./validate.sh
   ```

## Success Criteria
- Both WordPress and MySQL containers are running
- WordPress is accessible on port 80
- The validation script passes successfully

## Reward
Upon successful completion, you'll earn the "Orchestrator" badge!

## Troubleshooting
- View container logs: `docker-compose logs`
- Check if port 80 is already in use: `netstat -tuln | grep 80`
- Restart the containers: `docker-compose restart`
- If needed, reset everything: `docker-compose down -v` (this will delete all data)
