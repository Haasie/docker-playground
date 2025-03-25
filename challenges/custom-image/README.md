# Challenge 3: Image Architect

## Objective
Build a custom Docker image and push it to Azure Container Registry (ACR).

## Requirements
- Use the provided Dockerfile and application code
- Build the image with your username as a build argument
- Push the image to the private ACR
- Verify the image is accessible in ACR

## Steps

1. **Review the Dockerfile and application code**
   Take a moment to understand:
   - The Python Flask application in `app.py`
   - How the Dockerfile captures your username during the build process

2. **Build and push the image**
   ```bash
   ./build-and-push.sh
   ```
   
   This script will:
   - Build the image with your username as a build argument
   - Log in to your ACR instance
   - Push the image to ACR

3. **Validate your solution**
   ```bash
   ./validate.sh
   ```

## Success Criteria
- The image is successfully built with your username
- The image is pushed to ACR
- The validation script can pull the image and verify your username

## Reward
Upon successful completion, you'll earn the "ACR Pro" badge!

## Troubleshooting
- Make sure you're logged in to Azure: `az login`
- Check ACR access: `az acr login --name <acr-name>`
- Verify your image: `docker images`
- Check for build errors: `docker build --build-arg USERNAME="$(whoami)" -t myapp .`
