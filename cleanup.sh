#!/bin/bash
#
# Cleanup script for Docker Playground
# This script prepares the project for production by removing unnecessary files,
# fixing permissions, and ensuring consistent configurations.

set -e

echo "Starting Docker Playground cleanup process..."

# Base directory
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$BASE_DIR"

# Remove temporary and backup files
echo "Removing temporary and backup files..."
find . -type f -name "*.bak" -o -name "*.tmp" -o -name "*~" -o -name ".DS_Store" -o -name "*.swp" -o -name "*.log" -delete

# Ensure scripts are executable
echo "Setting correct permissions on scripts..."
find . -type f -name "*.sh" -exec chmod +x {} \;

# Ensure consistent line endings (convert CRLF to LF)
echo "Converting line endings to LF..."
find . -type f -not -path "*/\.*" -not -path "*/node_modules/*" -exec grep -Il $'\r' {} \; | xargs -r sed -i 's/\r$//'

# Remove any .env files with sensitive information (except example files)
echo "Removing sensitive .env files..."
find . -name ".env" -not -name ".env.example" -delete

# Clean up any leftover Docker containers and images from testing
echo "Cleaning up Docker artifacts..."
if command -v docker &> /dev/null; then
  docker container prune -f
  docker image prune -f
fi

# Ensure all challenge directories have proper validation scripts
echo "Verifying challenge directories..."
for challenge_dir in challenges/*/; do
  if [ ! -f "${challenge_dir}validate.sh" ]; then
    echo "Warning: Missing validate.sh in ${challenge_dir}"
  fi
done

# Remove any .git directories except the main one
echo "Cleaning up nested git repositories..."
find . -path "*/.git" -type d -not -path "./.git" -exec rm -rf {} \; 2>/dev/null || true

# Ensure all Ansible playbooks have proper YAML syntax
echo "Validating Ansible playbooks..."
if command -v ansible-lint &> /dev/null; then
  ansible-lint ansible/*.yml || echo "Ansible lint warnings found. Please review."
fi

echo "Cleanup complete! The Docker Playground is ready for production."
