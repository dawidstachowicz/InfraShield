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

# Construct target Azure Resource Group name and check its existence
AZ_GROUP_NAME="rg-${PROJECT}-tfstate-${AZURE_LOCATION}-${RESOURCE_SEQUENCE}"
AZ_GROUP_EXISTS=$(az group exists --name "${AZ_GROUP_NAME}" -o tsv)

# Define standardized Azure resource tags
AZ_RESOURCE_TAGS=(
    "Project=${TAG_PROJECT}"
    "Purpose=${TAG_PURPOSE}"
    "ManagedBy=${TAG_MANAGED_BY}"
    "Component=${TAG_COMPONENT}"
    "Owner=${TAG_OWNER}"
)

# Create Resource Group if it does not already exist
if [[ "${AZ_GROUP_EXISTS}" != "true" ]]; then
    az group create --name "${AZ_GROUP_NAME}" --location "${AZURE_LOCATION}" --tags "${AZ_RESOURCE_TAGS[@]}" -o none
else
    log_info "Resource group already exists, skipping: ${AZ_GROUP_NAME}"
fi

# Construct lock name and verify if CanNotDelete lock is present
AZ_LOCK_NAME="lock-${AZ_GROUP_NAME}-cannotdelete"
AZ_LOCK_EXISTS=$(az lock list --resource-group "${AZ_GROUP_NAME}" --query "[?level=='CanNotDelete'].name" -o tsv)

# Apply CanNotDelete lock to protect Resource Group from accidental deletion
if [[ -z "${AZ_LOCK_EXISTS}" ]]; then
    az lock create -o none \
      --name "${AZ_LOCK_NAME}" \
      --lock-type CanNotDelete \
      --resource-group "${AZ_GROUP_NAME}" \
      --notes "Protects the Terraform state resource group from accidental deletion."
else
    log_info "Resource group lock already exists, skipping: ${AZ_LOCK_NAME}"
fi