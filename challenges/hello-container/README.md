# Challenge 1: Hello Container

## Objective
Start an Nginx web server in a Docker container and expose it on port 8080.

## Requirements
- Use the provided Dockerfile to build an image
- Run a container from the image, exposing port 8080
- Verify the web server is accessible via browser or curl

## Steps

1. **Build the Docker image**
   ```bash
   docker build -t hello-nginx .
   ```

2. **Run the container**
   ```bash
   docker run -d -p 8080:80 hello-nginx
   ```

3. **Verify it's working**
   ```bash
   curl http://localhost:8080
   ```
   
   Or open a browser and navigate to: http://localhost:8080

4. **Validate your solution**
   ```bash
   ./validate.sh
   ```

## Success Criteria
- The Nginx web server is running in a Docker container
- The web server is accessible on port 8080
- The validation script passes successfully

## Reward
Upon successful completion, you'll earn the "Container Novice" badge!

## Troubleshooting
- Make sure Docker is running: `docker ps`
- Check if port 8080 is already in use: `netstat -tuln | grep 8080`
- View container logs: `docker logs <container_id>`
