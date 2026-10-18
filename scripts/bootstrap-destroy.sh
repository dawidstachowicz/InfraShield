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

# Set Azure Subscription ID
set_azure_subscription "${AZURE_SUBSCRIPTION_ID}" || exit 1

AZ_GROUP_NAME="rg-${PROJECT}-tfstate-${AZURE_LOCATION}-${RESOURCE_SEQUENCE}"

# Safety guard: nothing destructive runs unless explicitly confirmed in .env
if [[ "${CONFIRM_DESTROY}" != "true" ]]; then
    log_error "Destroy blocked. Set CONFIRM_DESTROY=\"true\" in .env to proceed."
    exit 1
fi

AZ_GROUP_EXISTS=$(az group exists --name "${AZ_GROUP_NAME}" -o tsv)
if [[ "${AZ_GROUP_EXISTS}" != "true" ]]; then
    log_error "Resource group does not exist: ${AZ_GROUP_NAME}"
    exit 1
fi

# Remove the CanNotDelete lock first, otherwise group delete is rejected
AZ_LOCK_GROUP_EXISTS=$(az lock list --resource-group "${AZ_GROUP_NAME}" --query "[?level=='CanNotDelete'].name" -o tsv)
if [[ -n "${AZ_LOCK_GROUP_EXISTS}" ]]; then
    az lock delete --name "${AZ_LOCK_GROUP_EXISTS}" --resource-group "${AZ_GROUP_NAME}"
fi

# Delete Resource Group
az group delete --name "${AZ_GROUP_NAME}" --yes
log_info "Resource group deleted: ${AZ_GROUP_NAME}"