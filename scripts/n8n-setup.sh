#!/bin/bash

# ------------------------------------------------- #
# Script to setup self-hosted N8N on a Linux System #
# ------------------------------------------------- #

# Update system
sudo apt-get update && sudo apt-get upgrade -y

# Install Lynis for system audit
sudo apt-get install -y lynis
sudo lynis audit system

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

# Install SQLite and Postgres client
sudo apt-get install -y sqlite3 postgresql-client

# Clone forked n8n repo
git clone https://github.com/PR-CYBR/n8n.git
cd n8n

# Download the latest docker-compose.yml file
curl -o docker-compose.yml https://raw.githubusercontent.com/PR-CYBR/n8n/master/.github/docker-compose.yml

# Prompt user for necessary details
read -p "Enter your DOMAIN_NAME: " DOMAIN_NAME
read -p "Enter your SSL_EMAIL: " SSL_EMAIL
read -p "Enter your N8N_BASIC_AUTH_USER: " N8N_BASIC_AUTH_USER
read -p "Enter your N8N_BASIC_AUTH_PASSWORD: " N8N_BASIC_AUTH_PASSWORD

# Copy .env.example to .env and set values
cp .env.example .env
sed -i "s/DOMAIN_NAME=.*/DOMAIN_NAME=$DOMAIN_NAME/" .env
sed -i "s/SSL_EMAIL=.*/SSL_EMAIL=$SSL_EMAIL/" .env
sed -i "s/N8N_BASIC_AUTH_USER=.*/N8N_BASIC_AUTH_USER=$N8N_BASIC_AUTH_USER/" .env
sed -i "s/N8N_BASIC_AUTH_PASSWORD=.*/N8N_BASIC_AUTH_PASSWORD=$N8N_BASIC_AUTH_PASSWORD/" .env

# Create Docker volume
docker volume create n8n_data

# Create volume for Traefik
docker volume create traefik_data

# Create n8n-audit directory
mkdir -p ~/n8n-audit

# Setup a cron job to run the `n8n-audit.sh` script once every hour
(crontab -l 2>/dev/null; echo "0 * * * * /path/to/n8n-audit.sh") | crontab -

echo "Setup complete. Please ensure that the n8n-audit.sh script is available at /path/to/n8n-audit.sh"