#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib/logging.sh
source "${SCRIPT_DIR}/lib/logging.sh"

EXIT_SUCCESS=0
EXIT_DEPENDENCY_FAILURE=10
EXIT_CREDENTIALS_MISSING=11
EXIT_SELF_TEST_FAILURE=12
EXIT_UNEXPECTED_FAILURE=99

trap 'log_error "Unhandled error on line ${LINENO}."; exit ${EXIT_UNEXPECTED_FAILURE}' ERR

REQUIRED_COMMANDS=(terraform tailscale zerotier-cli jq curl)
REQUIRED_CREDENTIALS=(
  "TERRAFORM_CLOUD_TOKEN|TF_TOKEN"
  "TAILSCALE_AUTHKEY"
  "ZEROTIER_CENTRAL_TOKEN|ZEROTIER_TOKEN"
)

_detect_execution_context() {
  if [[ "${CI:-}" == "true" || -n "${GITHUB_ACTIONS:-}" || -n "${AUTOMATION_CONTEXT:-}" ]]; then
    echo "automated"
  else
    echo "manual"
  fi
}

_validate_dependencies() {
  log_step "Validating required dependencies"
  local missing=()
  for cmd in "${REQUIRED_COMMANDS[@]}"; do
    if ! command -v "${cmd}" >/dev/null 2>&1; then
      missing+=("${cmd}")
      log_warn "Dependency missing: ${cmd}"
    else
      log_success "Found dependency: ${cmd}"
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    log_error "Missing ${#missing[@]} dependencies: ${missing[*]}"
    return 1
  fi

  return 0
}

_validate_credentials() {
  log_step "Validating Terraform, Tailscale, and ZeroTier credentials"
  local missing=()

  for credential_spec in "${REQUIRED_CREDENTIALS[@]}"; do
    IFS='|' read -r -a options <<<"${credential_spec}"
    local satisfied=false
    for option in "${options[@]}"; do
      if [[ -n "${!option:-}" ]]; then
        log_success "Credential detected: ${option}"
        satisfied=true
        break
      fi
    done
    if [[ "${satisfied}" == "false" ]]; then
      missing+=("${credential_spec}")
      log_warn "Credential not provided: ${credential_spec}"
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    log_error "Credential validation failed. Provide: ${missing[*]}"
    return 1
  fi

  return 0
}

_run_command_self_test() {
  local name="$1"
  shift
  local command=("$@")

  if ! command -v "${command[0]}" >/dev/null 2>&1; then
    log_warn "Skipping ${name} self-test: command not available"
    return 0
  fi

  if "${command[@]}" >/tmp/pr_cybr_setup_${name}.log 2>&1; then
    local output
    output=$(head -n 1 /tmp/pr_cybr_setup_${name}.log 2>/dev/null || true)
    log_success "${name} self-test passed${output:+: ${output}}"
    rm -f /tmp/pr_cybr_setup_${name}.log
    return 0
  else
    log_error "${name} self-test failed. Inspect /tmp/pr_cybr_setup_${name}.log for details."
    return 1
  fi
}

_run_self_tests() {
  log_step "Executing self-tests"
  local failures=0

  _run_command_self_test "terraform" terraform version || failures=$((failures + 1))
  _run_command_self_test "tailscale" tailscale version || failures=$((failures + 1))
  _run_command_self_test "zerotier" zerotier-cli -v || failures=$((failures + 1))

  if [[ ${failures} -gt 0 ]]; then
    log_error "Self-tests failed (${failures} component(s))"
    return 1
  fi

  log_success "All self-tests completed successfully"
  return 0
}

_main() {
  log_header "PR-CYBR setup validation"

  local context
  context=$(_detect_execution_context)
  log_kv "execution_context" "${context}"

  local exit_code=${EXIT_SUCCESS}

  if ! _validate_dependencies; then
    exit_code=${EXIT_DEPENDENCY_FAILURE}
  fi

  if [[ ${exit_code} -eq ${EXIT_SUCCESS} ]] && ! _validate_credentials; then
    exit_code=${EXIT_CREDENTIALS_MISSING}
  fi

  if [[ ${exit_code} -eq ${EXIT_SUCCESS} ]] && ! _run_self_tests; then
    exit_code=${EXIT_SELF_TEST_FAILURE}
  fi

  log_outcome "${exit_code}" "Setup inspection completed"
  return "${exit_code}"
}

_main "$@"
