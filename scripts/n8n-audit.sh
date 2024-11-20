#!/bin/bash

# Define the output file
AUDIT_OUTPUT_FILE=~/n8n-audit/n8n-audit-$(date +%Y%m%d%H%M%S).log

# Function to check the status of a Docker container
check_container_status() {
    local container_name=$1
    local status=$(docker inspect -f '{{.State.Status}}' "$container_name" 2>/dev/null)

    if [ "$status" == "running" ]; then
        echo "Container '$container_name' is running." >> "$AUDIT_OUTPUT_FILE"
    else
        echo "Container '$container_name' is NOT running. Status: $status" >> "$AUDIT_OUTPUT_FILE"
    fi
}

# Function to check the existence of a Docker volume
check_volume_exists() {
    local volume_name=$1
    local volume_exists=$(docker volume ls -q | grep -w "$volume_name")

    if [ -n "$volume_exists" ]; then
        echo "Volume '$volume_name' exists." >> "$AUDIT_OUTPUT_FILE"
    else
        echo "Volume '$volume_name' does NOT exist." >> "$AUDIT_OUTPUT_FILE"
    fi
}

# Run n8n audit and output to file
n8n audit >> "$AUDIT_OUTPUT_FILE"

# Check the status of the n8n, postgres, and tunnel containers
check_container_status "n8n"
check_container_status "postgres"
check_container_status "tunnel"

# Check the existence of the Docker volumes
check_volume_exists "n8n_data"
check_volume_exists "traefik_data"
check_volume_exists "postgres_data"

# Print a message indicating where the audit log is saved
echo "Audit completed. Output saved to $AUDIT_OUTPUT_FILE"