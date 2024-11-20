#!/bin/bash

# ------------------------------ #
# Script to build Docker images  #
# ------------------------------ #

# Define the repositories and their Docker Hub counterparts
REPOS=(
    "PR-CYBR-MGMT-AGENT"
    "PR-CYBR-DATA-INTEGRATION-AGENT"
    "PR-CYBR-DATABASE-AGENT"
    "PR-CYBR-FRONTEND-AGENT"
    "PR-CYBR-BACKEND-AGENT"
    "PR-CYBR-PERFORMANCE-AGENT"
    "PR-CYBR-SECURITY-AGENT"
    "PR-CYBR-TESTING-AGENT"
    "PR-CYBR-CI-CD-AGENT"
    "PR-CYBR-USER-FEEDBACK-AGENT"
    "PR-CYBR-DOCUMENTATION-AGENT"
    "PR-CYBR-INFRASTRUCTURE-AGENT"
)

# Docker Hub username
DOCKER_USERNAME=${DOCKER_USERNAME:-"your_docker_username"}

# Loop through each repository and build the Docker image
for REPO in "${REPOS[@]}"; do
    echo "Building Docker image for $REPO..."
    
    # Check if the directory exists
    if [ -d "$REPO" ]; then
        # Navigate to the repository directory
        cd "$REPO" || exit
        
        # Build the Docker image
        docker build -t "$DOCKER_USERNAME/$REPO:latest" .
        
        # Check if the build was successful
        if [ $? -ne 0 ]; then
            echo "Failed to build Docker image for $REPO. Exiting."
            exit 1
        fi
        
        # Navigate back to the parent directory
        cd ..
    else
        echo "Directory $REPO does not exist. Skipping."
    fi
done

echo "All Docker images built successfully."