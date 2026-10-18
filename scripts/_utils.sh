#!/usr/bin/env bash

# ==============================================================================
# Script Name: _utils.sh
# Description: Shared utility functions and logging.
# ==============================================================================

# Include guard to prevent double-sourcing
if [[ -n "${_UTILS_SH_LOADED:-}" ]]; then
    return 0
fi
readonly _UTILS_SH_LOADED=1

# ==============================================================================
# Terminal Color Definitions (ANSI Escape Sequences)
# Colors only when both stdout and stderr are terminals and NO_COLOR is unset
# ==============================================================================
if [[ -t 1 && -t 2 && -z "${NO_COLOR:-}" ]]; then
    readonly COLOR_GREEN='\033[1;32m'
    readonly COLOR_RED='\033[1;31m'
    readonly COLOR_RESET='\033[0m'
else
    readonly COLOR_GREEN=''
    readonly COLOR_RED=''
    readonly COLOR_RESET=''
fi

log_info() {
    local message="$1"
    printf "[%b%s%b] %s\n" "${COLOR_GREEN}" "INFO" "${COLOR_RESET}" "${message}"
}

log_error() {
    local message="$1"
    printf "[%b%s%b] %s\n" "${COLOR_RED}" "ERROR" "${COLOR_RESET}" "${message}" >&2
}

load_environment() {
    local env_file="$1"

    if [[ ! -f "${env_file}" ]]; then
        log_error "Missing required .env file. Rename bootstrap.env.example to .env and configure variables."
        return 1
    fi

    # shellcheck source=/dev/null
    # .env is gitignored (secrets) and absent on fresh clones; intentionally not analyzed.
    source "${env_file}"
}

check_azure_cli() {
    if ! command -v az &>/dev/null; then
        log_error "Azure CLI (az) is not installed. Please install it first."
        return 1
    fi

    if ! az account show &>/dev/null; then
        log_error "You are not logged in to Azure CLI. Run az login first."
        return 1
    fi
}

set_azure_subscription() {

    local subscription_id="$1"

    if ! az account set --subscription "${subscription_id}"; then
        log_error "Could not set Azure subscription: ${subscription_id}"
        return 1
    fi
}