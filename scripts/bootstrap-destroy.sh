#!/usr/bin/env bash

# ==============================================================================
# Script Name: bootstrap-destroy.sh
# Description: Azure infrastructure bootstrap teardown script.
# ==============================================================================

# Strict mode: fail on error or unset vars
set -euo pipefail

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_SCRIPT="${SCRIPT_DIR}/_utils.sh"
PROJECT_DIR="${SCRIPT_DIR}/.."
ENV_FILE="${PROJECT_DIR}/.env"

# Verify and load shared utilities
if [[ ! -f "${COMMON_SCRIPT}" ]]; then
    printf "[ERROR] Missing required helper script: %s\n" "${COMMON_SCRIPT}" >&2
    exit 1
fi

# shellcheck source-path=SCRIPTDIR
# shellcheck source=_utils.sh
source "${COMMON_SCRIPT}"

# Load .env file
load_environment "${ENV_FILE}" || exit 1

# Check if Azure CLI is ready
check_azure_cli || exit 1