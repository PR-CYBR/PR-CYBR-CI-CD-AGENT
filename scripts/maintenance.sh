#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib/logging.sh
source "${SCRIPT_DIR}/lib/logging.sh"

EXIT_SUCCESS=0
EXIT_HITL_BLOCKED=20
EXIT_VALIDATION_FAILURE=21
EXIT_HEALTHCHECK_FAILURE=22
EXIT_SYNC_FAILURE=23
EXIT_UNEXPECTED_FAILURE=99

trap 'log_error "Unhandled error on line ${LINENO}."; exit ${EXIT_UNEXPECTED_FAILURE}' ERR

LOG_DIR="${SCRIPT_DIR}/../logs"
MAINTENANCE_LOG="${LOG_DIR}/maintenance.log"

_required_environment() {
  local missing=()
  local commands=(terraform tailscale zerotier-cli)

  for cmd in "${commands[@]}"; do
    if ! command -v "${cmd}" >/dev/null 2>&1; then
      log_warn "Operational dependency missing: ${cmd}"
      missing+=("${cmd}")
    else
      log_success "Operational dependency detected: ${cmd}"
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    log_warn "Continuing despite missing commands: ${missing[*]}"
    return 1
  fi

  return 0
}

_enforce_hitl_gate() {
  local required="${HITL_REQUIRED:-${HITL_GATE_REQUIRED:-false}}"
  local approved="${HITL_APPROVED:-false}"

  if [[ "${required}" == "true" && "${approved}" != "true" ]]; then
    log_error "HITL approval is required but not granted. Set HITL_APPROVED=true to continue."
    return 1
  fi

  if [[ "${approved}" == "true" ]]; then
    log_success "HITL approval confirmed."
  else
    log_info "HITL approval not requested; proceeding with default safeguards."
  fi

  return 0
}

_perform_health_checks() {
  log_step "Running platform health checks"
  local failures=0

  local disk_usage
  disk_usage=$(df -Ph . | awk 'NR==2 {gsub("%", "", $5); print $5}')
  if [[ -n "${disk_usage}" && "${disk_usage}" -ge 90 ]]; then
    log_error "Disk usage is at ${disk_usage}% (>=90%)."
    failures=$((failures + 1))
  else
    log_success "Disk usage healthy: ${disk_usage:-unknown}%"
  fi

  if command -v tailscale >/dev/null 2>&1; then
    if tailscale status --peers=false >/tmp/pr_cybr_tailscale_status.log 2>&1; then
      log_success "Tailscale status check passed"
      rm -f /tmp/pr_cybr_tailscale_status.log
    else
      log_warn "Tailscale status check could not complete; see /tmp/pr_cybr_tailscale_status.log"
    fi
  fi

  if command -v zerotier-cli >/dev/null 2>&1; then
    if zerotier-cli info >/tmp/pr_cybr_zerotier_info.log 2>&1; then
      log_success "ZeroTier info check passed"
      rm -f /tmp/pr_cybr_zerotier_info.log
    else
      log_warn "ZeroTier info check reported issues; see /tmp/pr_cybr_zerotier_info.log"
    fi
  fi

  if [[ ${failures} -gt 0 ]]; then
    return 1
  fi

  log_success "Platform health checks completed"
  return 0
}

_rotate_logs() {
  log_step "Rotating maintenance logs"
  mkdir -p "${LOG_DIR}"
  if [[ -f "${MAINTENANCE_LOG}" ]]; then
    local timestamp
    timestamp=$(date -u '+%Y%m%dT%H%M%SZ')
    mv "${MAINTENANCE_LOG}" "${MAINTENANCE_LOG}.${timestamp}"
    log_info "Archived prior log as maintenance.log.${timestamp}"
  fi
  touch "${MAINTENANCE_LOG}"
  log_success "Active log file ready at ${MAINTENANCE_LOG}"
}

_synchronization_hooks() {
  log_step "Processing synchronization hooks"

  if [[ -n "${ZAPIER_WEBHOOK_URL:-}" ]]; then
    log_info "Zapier webhook queued: ${ZAPIER_WEBHOOK_URL}"
  else
    log_warn "No Zapier webhook configured (set ZAPIER_WEBHOOK_URL to enable)."
  fi

  if [[ -n "${N8N_WEBHOOK_URL:-}" ]]; then
    log_info "n8n webhook queued: ${N8N_WEBHOOK_URL}"
  else
    log_warn "No n8n webhook configured (set N8N_WEBHOOK_URL to enable)."
  fi

  if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
    log_info "GitHub Actions context detected."
    if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
      {
        echo "### Maintenance Summary"
        echo "- Execution time (UTC): $(_log_timestamp)"
        echo "- Host: $(hostname)"
      } >>"${GITHUB_STEP_SUMMARY}"
      log_success "Appended maintenance summary to $GITHUB_STEP_SUMMARY"
    fi
  else
    log_info "Non-GitHub context; skipped Actions-specific sync."
  fi

  return 0
}

_main() {
  log_header "PR-CYBR maintenance cycle"

  local exit_code=${EXIT_SUCCESS}

  if ! _enforce_hitl_gate; then
    exit_code=${EXIT_HITL_BLOCKED}
  fi

  if [[ ${exit_code} -eq ${EXIT_SUCCESS} ]]; then
    if ! _required_environment; then
      exit_code=${EXIT_VALIDATION_FAILURE}
    fi
  fi

  if [[ ${exit_code} -eq ${EXIT_SUCCESS} ]]; then
    if ! _perform_health_checks; then
      exit_code=${EXIT_HEALTHCHECK_FAILURE}
    fi
  fi

  if [[ ${exit_code} -eq ${EXIT_SUCCESS} ]]; then
    _rotate_logs
    if ! _synchronization_hooks; then
      exit_code=${EXIT_SYNC_FAILURE}
    fi
  fi

  log_outcome "${exit_code}" "Maintenance cycle complete"
  return "${exit_code}"
}

_main "$@"
