#!/bin/bash

# Update system
sudo apt-get update && sudo apt-get upgrade -y

# Check for latest Docker Hub container release
latest_version=$(curl -s https://hub.docker.com/v2/repositories/pr-cybr/n8n/tags | jq -r '.results[0].name')
current_version=$(docker images pr-cybr/n8n --format "{{.Tag}}" | head -n 1)

if [ "$latest_version" != "$current_version" ]; then
  echo "New version available: $latest_version"
  read -p "Do you want to update to the latest version? (y/n): " choice
  if [ "$choice" == "y" ]; then
    docker pull pr-cybr/n8n:$latest_version
    docker-compose up -d
  fi
fi

# Trigger the n8n-setup-test.yml workflow
curl -X POST -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/PR-CYBR/n8n/actions/workflows/n8n-setup-test.yml/dispatches \
  -d '{"ref":"main"}'