#!/bin/bash

# ------------------------------ #
# Key Objectives for this script #
#
# 1. Update system
# 2. Script should be triggered when running `zerotier-conf.sh`
# 3. Checks `.github/nginx.conf` for current settings
# 4. If IP = local / system, change to Zerotier IP (so it is proxied through the Zerotier IP)
# 5. Save changes
# 6. Print success message explaining the changes / updates made

NGINX_CONF=".github/nginx.conf"
LOG_FILE="nginx-sync.log"

# Function to log messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE
}

# Update system
log "Updating system..."
sudo apt-get update && sudo apt-get upgrade -y

# Get the ZeroTier IP address
ZEROTIER_IP=$(ip -4 addr show zt+ | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
if [ -z "$ZEROTIER_IP" ]; then
    log "ZeroTier IP not found. Ensure ZeroTier is installed and connected."
    exit 1
fi
log "ZeroTier IP found: $ZEROTIER_IP"

# Check and update NGINX configuration
if [ -f "$NGINX_CONF" ]; then
    log "Checking NGINX configuration at $NGINX_CONF..."
    if grep -q "server_name localhost;" "$NGINX_CONF"; then
        log "Localhost found in NGINX configuration. Updating to ZeroTier IP..."
        sed -i "s/server_name localhost;/server_name $ZEROTIER_IP;/" "$NGINX_CONF"
        log "NGINX configuration updated to use ZeroTier IP: $ZEROTIER_IP"
    else
        log "No localhost entry found in NGINX configuration. No changes made."
    fi
else
    log "NGINX configuration file not found at $NGINX_CONF."
    exit 1
fi

# Print success message
log "NGINX configuration sync completed successfully."
echo "NGINX configuration updated to use ZeroTier IP: $ZEROTIER_IP. Check $LOG_FILE for details."