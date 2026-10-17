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
    readonly COLOR_YELLOW='\033[1;33m'
    readonly COLOR_RED='\033[1;31m'
    readonly COLOR_RESET='\033[0m'
else
    readonly COLOR_GREEN=''
    readonly COLOR_YELLOW=''
    readonly COLOR_RED=''
    readonly COLOR_RESET=''
fi

log_info() {
    local message="$1"
    printf "[%b%s%b] %s\n" "${COLOR_GREEN}" "INFO" "${COLOR_RESET}" "${message}"
}

log_warn() {
    local message="$1"
    printf "[%b%s%b] %s\n" "${COLOR_YELLOW}" "WARN" "${COLOR_RESET}" "${message}"
}

log_error() {
    local message="$1"
    printf "[%b%s%b] %s\n" "${COLOR_RED}" "ERROR" "${COLOR_RESET}" "${message}" >&2
}