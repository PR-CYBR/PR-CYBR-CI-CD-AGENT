#!/usr/bin/env bash
# Shared logging helpers for PR-CYBR scripts.
# Provides consistent, timestamped, and colorized output that is suitable for
# HITL (Human-In-The-Loop) review across automated and manual contexts.

if [[ -n "${PR_CYBR_LOGGING_LIB_SOURCED:-}" ]]; then
  return 0
fi
export PR_CYBR_LOGGING_LIB_SOURCED=1

# shellcheck disable=SC2034
LOG_COLOR_RESET="\033[0m"
LOG_COLOR_INFO="\033[1;34m"
LOG_COLOR_WARN="\033[1;33m"
LOG_COLOR_ERROR="\033[1;31m"
LOG_COLOR_SUCCESS="\033[1;32m"
LOG_COLOR_STEP="\033[1;36m"

_log_timestamp() {
  date -u '+%Y-%m-%dT%H:%M:%SZ'
}

_log_print() {
  local level="$1"
  local color="$2"
  local message="$3"
  printf '%b[%s] [%s] %s%b\n' "${color}" "$(_log_timestamp)" "${level}" "${message}" "${LOG_COLOR_RESET}"
}

log_info() {
  _log_print "INFO" "${LOG_COLOR_INFO}" "$*"
}

log_warn() {
  _log_print "WARN" "${LOG_COLOR_WARN}" "$*"
}

log_error() {
  _log_print "ERROR" "${LOG_COLOR_ERROR}" "$*"
}

log_success() {
  _log_print "OK" "${LOG_COLOR_SUCCESS}" "$*"
}

log_step() {
  _log_print "STEP" "${LOG_COLOR_STEP}" "$*"
}

log_header() {
  local border
  border="$(printf '=%.0s' {1..60})"
  log_step "${border}"
  log_step "$*"
  log_step "${border}"
}

log_kv() {
  local key="$1"
  shift
  local value="$*"
  log_info "${key}: ${value}"
}

log_outcome() {
  local code="$1"
  shift
  local message="$*"
  if [[ "${code}" -eq 0 ]]; then
    log_success "${message} (exit=${code})"
  else
    log_error "${message} (exit=${code})"
  fi
}

