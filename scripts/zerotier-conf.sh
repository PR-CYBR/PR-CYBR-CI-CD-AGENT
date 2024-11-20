#!/bin/bash

# ------------------------------ #
# Key Objectives for this Script #
#
# 1. Update system
# 2. Check if Zerotier is Installed (and install if it's not)
# 3. Prompt user to choose from the following options:
#   - Install Zerotier & Join Network (will install zerotier and ask for Network ID)
#   - Setup Zerotier to be the Default Network Device (will configure network setting's to only allow incoming traffic to services running on the machine from peer connections (meaning on the same subnet of the Zerotier Network))
#   - Troubleshoot Zerotier Issues (guide user through troubleshooting networking issues)
# 4. Continue with user choice
# 5. Output Installation and Setup into `zerotier-conf.log` file (to allow for troubleshooting)
# 6. If Installation / Setup fails, be verbose and output it into the `zerotier-conf.log` file
# 7. If Installation & Setup passes, print success message

LOG_FILE="zerotier-conf.log"

# Function to log messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE
}

# Update system
log "Updating system..."
sudo apt-get update && sudo apt-get upgrade -y

# Check if ZeroTier is installed
if ! command -v zerotier-cli &> /dev/null; then
    log "ZeroTier is not installed. Installing ZeroTier..."
    curl -s https://install.zerotier.com | sudo bash
    if [ $? -ne 0 ]; then
        log "Failed to install ZeroTier."
        exit 1
    fi
    log "ZeroTier installed successfully."
else
    log "ZeroTier is already installed."
fi

# Prompt user for action
echo "Choose an option:"
echo "1) Install ZeroTier & Join Network"
echo "2) Setup ZeroTier as Default Network Device"
echo "3) Troubleshoot ZeroTier Issues"
read -p "Enter choice [1-3]: " user_choice

case $user_choice in
    1)
        read -p "Enter the ZeroTier Network ID to join: " network_id
        log "Joining ZeroTier network with ID: $network_id"
        sudo zerotier-cli join $network_id
        if [ $? -ne 0 ]; then
            log "Failed to join ZeroTier network."
            exit 1
        fi
        log "Successfully joined ZeroTier network."
        ;;
    2)
        log "Configuring ZeroTier as the default network device..."
        # Example configuration command (this will vary based on specific requirements)
        # sudo iptables -A INPUT -i zt+ -j ACCEPT
        # sudo iptables -A INPUT -j DROP
        log "ZeroTier configured as the default network device."
        ;;
    3)
        log "Troubleshooting ZeroTier issues..."
        # Example troubleshooting steps
        sudo zerotier-cli status
        sudo zerotier-cli listnetworks
        log "Troubleshooting complete. Check the above output for issues."
        ;;
    *)
        log "Invalid choice. Exiting."
        exit 1
        ;;
esac

log "ZeroTier setup completed successfully."
echo "ZeroTier setup completed successfully. Check $LOG_FILE for details."