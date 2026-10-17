#!/usr/bin/env bash

# ==============================================================================
# Script Name: bootstrap-build.sh
# Description: Azure infrastructure bootstrap build script.
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

#Load .env file
load_environment "${ENV_FILE}" || exit 1

# Check if Azure CLI is ready
check_azure_cli || exit 1

#Set Azure Subscription ID
set_azure_subscription "${AZURE_SUBSCRIPTION_ID}" || exit 1

AZ_GROUP_NAME="rg-${PROJECT}-tfstate-${AZURE_LOCATION}-${RESOURCE_SEQUENCE}"
AZ_GROUP_EXISTS=$(az group exists --name "${AZ_GROUP_NAME}" -o tsv)
AZ_RESOURCE_TAGS=(
    "Project=${TAG_PROJECT}"
    "Purpose=${TAG_PURPOSE}"
    "ManagedBy=${TAG_MANAGED_BY}"
    "Component=${TAG_COMPONENT}"
    "Owner=${TAG_OWNER}"
)

if  [[ "${AZ_GROUP_EXISTS}" == "true" ]]; then
    log_error "This resource group already exists ${AZ_GROUP_NAME}"
    exit 1
fi

az group create --name "${AZ_GROUP_NAME}" --location "${AZURE_LOCATION}" --tags "${AZ_RESOURCE_TAGS[@]}" -o none