#!/bin/bash

# ------------------------------------------------- #
# Script to setup self-hosted N8N on a Linux System #
# ------------------------------------------------- #

# Update system
sudo apt-get update && sudo apt-get upgrade -y

# Install Lynis for system audit
sudo apt-get install -y lynis
sudo lynis audit system

# Prompt user for setup method
echo "Choose setup method:"
echo "1) Docker"
echo "2) npm"
read -p "Enter choice [1 or 2]: " setup_choice

# Prompt user for necessary details
read -p "Enter your DOMAIN_NAME: " DOMAIN_NAME
read -p "Enter your SSL_EMAIL: " SSL_EMAIL
read -p "Enter your N8N_BASIC_AUTH_USER: " N8N_BASIC_AUTH_USER
read -p "Enter your N8N_BASIC_AUTH_PASSWORD: " N8N_BASIC_AUTH_PASSWORD

if [ "$setup_choice" == "1" ]; then
    # Docker setup
    echo "Setting up n8n using Docker..."

    # Install Docker and Docker Compose
    sudo apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release

    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

    # Clone forked n8n repo
    git clone https://github.com/PR-CYBR/n8n.git
    cd n8n

    # Download the latest docker-compose.yml file
    curl -o docker-compose.yml https://raw.githubusercontent.com/PR-CYBR/n8n/master/.github/docker-compose.yml

    # Copy .env.example to .env and set values
    cp .env.example .env
    sed -i "s/DOMAIN_NAME=.*/DOMAIN_NAME=$DOMAIN_NAME/" .env
    sed -i "s/SSL_EMAIL=.*/SSL_EMAIL=$SSL_EMAIL/" .env
    sed -i "s/N8N_BASIC_AUTH_USER=.*/N8N_BASIC_AUTH_USER=$N8N_BASIC_AUTH_USER/" .env
    sed -i "s/N8N_BASIC_AUTH_PASSWORD=.*/N8N_BASIC_AUTH_PASSWORD=$N8N_BASIC_AUTH_PASSWORD/" .env

    # Pull the latest n8n container
    docker compose pull

    # Start Docker containers
    docker compose up -d

elif [ "$setup_choice" == "2" ]; then
    # npm setup
    echo "Setting up n8n using npm..."

    # Install Node.js and npm
    curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -
    sudo apt-get install -y nodejs

    # Install pnpm
    npm install -g pnpm

    # Clone forked n8n repo
    git clone https://github.com/PR-CYBR/n8n.git
    cd n8n

    # Install dependencies and build
    pnpm install --frozen-lockfile
    pnpm run build

    # Copy .env.example to .env and set values
    cp .env.example .env
    sed -i "s/DOMAIN_NAME=.*/DOMAIN_NAME=$DOMAIN_NAME/" .env
    sed -i "s/SSL_EMAIL=.*/SSL_EMAIL=$SSL_EMAIL/" .env
    sed -i "s/N8N_BASIC_AUTH_USER=.*/N8N_BASIC_AUTH_USER=$N8N_BASIC_AUTH_USER/" .env
    sed -i "s/N8N_BASIC_AUTH_PASSWORD=.*/N8N_BASIC_AUTH_PASSWORD=$N8N_BASIC_AUTH_PASSWORD/" .env

    # Start n8n
    pnpm run start

else
    echo "Invalid choice. Exiting."
    exit 1
fi

# Create n8n-audit directory
mkdir -p ~/n8n-audit

# Determine the current working directory and set it as an environment variable
CURRENT_DIR=$(pwd)
echo "N8N_AUDIT_SCRIPT_PATH=$CURRENT_DIR/n8n-audit.sh" >> .env

# Setup a cron job to run the `n8n-audit.sh` script once every hour using the environment variable
(crontab -l 2>/dev/null; echo "0 * * * * $CURRENT_DIR/n8n-audit.sh") | crontab -

# Print access information
echo "Setup complete. You can access n8n at http://$DOMAIN_NAME:5678"
echo "Please ensure that the n8n-audit.sh script is available at $CURRENT_DIR/n8n-audit.sh"