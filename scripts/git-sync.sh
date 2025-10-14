#!/bin/bash

# ------------------------------ #
# Key Objectives for this script #
#
# 1. Update system
# 2. Check if Git is Installed (and install if not), if installed check for agent repo's (if they exist, end script with a success message, if they do not exist, proceed with next steps)
# 3. Prompt user for their Github Username / Email (what will be used for git commit's, pushes, etc.)
# 4. Ask user if they would like to setup a new SSH Key & Copy it over to Github (then run test)
# 5. Ask user to choose which agent clone:
#   - PR-CYBR-MGMT-AGENT (Repo: https://github.com/PR-CYBR/PR-CYBR-MGMT-AGENT)
#   - PR-CYBR-DATA-INTEGRATION-AGENT (Repo: https://github.com/PR-CYBR/PR-CYBR-DATA-INTEGRATION-AGENT)
#   - PR-CYBR-DATABASE-AGENT (Repo: https://github.com/PR-CYBR/PR-CYBR-DATABASE-AGENT)
#   - PR-CYBR-FRONTEND-AGENT (Repo: https://github.com/PR-CYBR/PR-CYBR-FRONTEND-AGENT)
#   - PR-CYBR-BACKEND-AGENT (Repo: https://github.com/PR-CYBR/PR-CYBR-BACKEND-AGENT)
#   - PR-CYBR-PERFORMANCE-AGENT (Repo: https://github.com/PR-CYBR/PR-CYBR-PERFORMANCE-AGENT)
#   - PR-CYBR-SECURITY-AGENT (Repo: https://github.com/PR-CYBR/PR-CYBR-SECURITY-AGENT)
#   - PR-CYBR-TESTING-AGENT (Repo: https://github.com/PR-CYBR/PR-CYBR-TESTING-AGENT)
#   - PR-CYBR-CI-CD-AGENT (Repo: https://github.com/PR-CYBR/PR-CYBR-CI-CD-AGENT)
#   - PR-CYBR-USER-FEEDBACK-AGENT (Repo: https://github.com/PR-CYBR/PR-CYBR-USER-FEEDBACK-AGENT)
#   - PR-CYBR-DOCUMENTATION-AGENT (Repo: https://github.com/PR-CYBR/PR-CYBR-DOCUMENTATION-AGENT)
#   - PR-CYBR-INFRASTRUCTURE-AGENT (Repo: https://github.com/PR-CYBR/PR-CYBR-INFRASTRUCTURE-AGENT)
#   - All Agents
# 6. Git clone Repo(s) and cd into Repo (if cloned all, cd into mgmt agent)
# 7. Prompt user for new branch name
# 8. Create new branch (one that user set)
# 9. Sync with `main` branch (to test git and ssh works)
# 10. Print to user that they now can apply changes and make git commits to the `<branch-name-user-picked>` branch
# 11. Ask user if they would like to setup a cron job to sync / pull their branch with the main branch (for one, or all agents)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_ROOT="${LOG_ROOT:-"${REPO_ROOT}/logs/automation"}"
mkdir -p "${LOG_ROOT}"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
LOG_FILE="${LOG_FILE:-"${LOG_ROOT}/git-sync-${TIMESTAMP}.jsonl"}"

escape_json() {
    printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

log_event() {
    local level="$1"
    local action="$2"
    local status="${3:-}"
    local message="${4:-}"
    local console_message="${5:-${4:-}}"
    local extra=""

    if [[ -n "${status}" ]]; then
        extra+=$(printf ',"status":"%s"' "$(escape_json "${status}")")
    fi

    if [[ -n "${message}" ]]; then
        extra+=$(printf ',"message":"%s"' "$(escape_json "${message}")")
    fi

    printf '{"timestamp":"%s","level":"%s","action":"%s"%s}\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        "$(escape_json "${level}")" \
        "$(escape_json "${action}")" \
        "${extra}" >> "${LOG_FILE}"

    if [[ -n "${console_message}" ]]; then
        echo "[${level^^}] ${console_message}"
    else
        echo "[${level^^}] ${action} ${status}"
    fi
}

log_event "info" "script_started" "running" "Preparing PR-CYBR git sync helper"

# Update system
log_event "info" "system_update" "started" "Starting package refresh." "Updating system packages..."
if sudo apt-get update && sudo apt-get upgrade -y; then
    log_event "info" "system_update" "succeeded" "Package refresh completed." "System packages updated."
else
    log_event "error" "system_update" "failed" "Package manager exited with an error."
    exit 1
fi

# Check if Git is installed
if ! command -v git &> /dev/null; then
    log_event "info" "git_check" "installing" "Git not detected; attempting installation." "Git is not installed. Installing Git..."
    if sudo apt-get install -y git; then
        log_event "info" "git_check" "succeeded" "Git installation completed." "Git installed successfully."
    else
        log_event "error" "git_check" "failed" "Package manager could not install Git."
        exit 1
    fi
else
    log_event "info" "git_check" "present" "Git already available." "Git is already installed."
fi

# Check for existing agent repositories
AGENT_REPOS=("PR-CYBR-MGMT-AGENT" "PR-CYBR-DATA-INTEGRATION-AGENT" "PR-CYBR-DATABASE-AGENT" "PR-CYBR-FRONTEND-AGENT" "PR-CYBR-BACKEND-AGENT" "PR-CYBR-PERFORMANCE-AGENT" "PR-CYBR-SECURITY-AGENT" "PR-CYBR-TESTING-AGENT" "PR-CYBR-CI-CD-AGENT" "PR-CYBR-USER-FEEDBACK-AGENT" "PR-CYBR-DOCUMENTATION-AGENT" "PR-CYBR-INFRASTRUCTURE-AGENT")
EXISTING_REPOS=0

for repo in "${AGENT_REPOS[@]}"; do
    if [ -d "$repo" ]; then
        log_event "info" "repository_check" "exists" "Repository ${repo} already exists." "Repository $repo already exists."
        EXISTING_REPOS=$((EXISTING_REPOS + 1))
    fi
done

if [ $EXISTING_REPOS -eq ${#AGENT_REPOS[@]} ]; then
    log_event "info" "repository_check" "complete" "All tracked repositories already exist."
    exit 0
fi

# Prompt user for GitHub username and email
read -p "Enter your GitHub username: " GITHUB_USERNAME
read -p "Enter your GitHub email: " GITHUB_EMAIL

# Configure Git
git config --global user.name "$GITHUB_USERNAME"
git config --global user.email "$GITHUB_EMAIL"
log_event "info" "git_config" "succeeded" "Git user configuration applied." "Git configuration updated."

# Ask user if they want to set up a new SSH key
read -p "Would you like to set up a new SSH key and add it to GitHub? (y/n): " setup_ssh
if [ "$setup_ssh" == "y" ]; then
    ssh-keygen -t rsa -b 4096 -C "$GITHUB_EMAIL" -f ~/.ssh/id_rsa -N ""
    eval "$(ssh-agent -s)"
    ssh-add ~/.ssh/id_rsa
    log_event "info" "ssh_key" "generated" "New SSH key pair generated." "SSH key generated."

    # Display the SSH key and prompt user to add it to GitHub
    echo "Copy the following SSH key to your GitHub account:"
    cat ~/.ssh/id_rsa.pub
    read -p "Press enter after adding the SSH key to GitHub..."

    # Test SSH connection
    ssh -T git@github.com
    if [ $? -ne 1 ]; then
        log_event "error" "ssh_test" "failed" "SSH authentication with GitHub failed."
        exit 1
    fi
    log_event "info" "ssh_test" "succeeded" "SSH authentication confirmed." "SSH connection to GitHub successful."
else
    log_event "info" "ssh_key" "skipped" "User opted to skip SSH key generation."
fi

# Prompt user to choose which agent to clone
echo "Choose which agent to clone:"
echo "1) PR-CYBR-MGMT-AGENT"
echo "2) PR-CYBR-DATA-INTEGRATION-AGENT"
echo "3) PR-CYBR-DATABASE-AGENT"
echo "4) PR-CYBR-FRONTEND-AGENT"
echo "5) PR-CYBR-BACKEND-AGENT"
echo "6) PR-CYBR-PERFORMANCE-AGENT"
echo "7) PR-CYBR-SECURITY-AGENT"
echo "8) PR-CYBR-TESTING-AGENT"
echo "9) PR-CYBR-CI-CD-AGENT"
echo "10) PR-CYBR-USER-FEEDBACK-AGENT"
echo "11) PR-CYBR-DOCUMENTATION-AGENT"
echo "12) PR-CYBR-INFRASTRUCTURE-AGENT"
echo "13) All Agents"
read -p "Enter choice [1-13]: " agent_choice

REPO_URLS=(
    "https://github.com/PR-CYBR/PR-CYBR-MGMT-AGENT"
    "https://github.com/PR-CYBR/PR-CYBR-DATA-INTEGRATION-AGENT"
    "https://github.com/PR-CYBR/PR-CYBR-DATABASE-AGENT"
    "https://github.com/PR-CYBR/PR-CYBR-FRONTEND-AGENT"
    "https://github.com/PR-CYBR/PR-CYBR-BACKEND-AGENT"
    "https://github.com/PR-CYBR/PR-CYBR-PERFORMANCE-AGENT"
    "https://github.com/PR-CYBR/PR-CYBR-SECURITY-AGENT"
    "https://github.com/PR-CYBR/PR-CYBR-TESTING-AGENT"
    "https://github.com/PR-CYBR/PR-CYBR-CI-CD-AGENT"
    "https://github.com/PR-CYBR/PR-CYBR-USER-FEEDBACK-AGENT"
    "https://github.com/PR-CYBR/PR-CYBR-DOCUMENTATION-AGENT"
    "https://github.com/PR-CYBR/PR-CYBR-INFRASTRUCTURE-AGENT"
)

if [ "$agent_choice" -eq 13 ]; then
    for url in "${REPO_URLS[@]}"; do
        git clone "$url"
    done
    cd PR-CYBR-MGMT-AGENT
else
    git clone "${REPO_URLS[$((agent_choice-1))]}"
    cd "${AGENT_REPOS[$((agent_choice-1))]}"
fi

# Prompt user for new branch name
read -p "Enter the new branch name: " branch_name

# Create new branch
git checkout -b "$branch_name"
log_event "info" "branch_create" "succeeded" "Branch created." "New branch '$branch_name' created."

# Sync with main branch
git fetch origin
git merge origin/main
log_event "info" "branch_sync" "succeeded" "Branch synced with main." "Branch '$branch_name' synced with 'main'."

# Inform user
log_event "info" "next_steps" "ready" "Branch ready for development." "You can now apply changes and make git commits to the '$branch_name' branch."

# Ask user if they want to set up a cron job for syncing
read -p "Would you like to set up a cron job to sync your branch with the main branch? (y/n): " setup_cron
if [ "$setup_cron" == "y" ]; then
    CRON_CMD="cd $(pwd) && git fetch origin && git merge origin/main"
    (crontab -l 2>/dev/null; echo "0 * * * * $CRON_CMD") | crontab -
    log_event "info" "cron_setup" "succeeded" "Hourly sync cron job created." "Cron job set up to sync branch '$branch_name' with 'main' every hour."
fi

log_event "info" "script_completed" "success" "Git sync workflow completed."
