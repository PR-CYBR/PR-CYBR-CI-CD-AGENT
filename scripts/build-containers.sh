#!/bin/bash

set -euo pipefail

# ------------------------------ #
# Script to build Docker images  #
# ------------------------------ #

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_ROOT="${LOG_ROOT:-"${REPO_ROOT}/logs/automation"}"
mkdir -p "${LOG_ROOT}"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
LOG_FILE="${LOG_FILE:-"${LOG_ROOT}/build-containers-${TIMESTAMP}.jsonl"}"

escape_json() {
    printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

log_event() {
    local level="$1"
    local action="$2"
    local status="${3:-}"
    local message="${4:-}"
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
        "${extra}" | tee -a "${LOG_FILE}"
}

log_event "info" "script_started" "running" "Building Docker images"

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
    if [[ -d "${REPO}" ]]; then
        log_event "info" "docker_build" "started" "${REPO}"
        pushd "${REPO}" >/dev/null
        if docker build -t "${DOCKER_USERNAME}/${REPO}:latest" .; then
            log_event "info" "docker_build" "succeeded" "${REPO}"
        else
            log_event "error" "docker_build" "failed" "${REPO}"
            exit 1
        fi
        popd >/dev/null
    else
        log_event "warning" "repository_missing" "skipped" "${REPO}"
    fi
done

log_event "info" "script_completed" "success" "All Docker images built"
