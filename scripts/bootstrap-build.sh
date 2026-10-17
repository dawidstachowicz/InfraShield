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


# Validate Storage Account name format (3-24 lowercase alphanumeric characters)
if [[ ! "${AZURE_STORAGE_ACCOUNT_NAME}" =~ ^[a-z0-9]{3,24}$ ]]; then
    log_error "Invalid storage account name (3-24 chars, lowercase letters and digits only): ${AZURE_STORAGE_ACCOUNT_NAME}"
    exit 1
fi

# Check if the Storage Account already exists in the target Resource Group
AZ_STORAGE_ACCOUNT_EXISTS=$(az storage account list \
    --resource-group "${AZ_GROUP_NAME}" \
    --query "[?name=='${AZURE_STORAGE_ACCOUNT_NAME}'].name" \
    -o tsv)

# Create Storage Account if it does not exist in the Resource Group
if [[ -z "${AZ_STORAGE_ACCOUNT_EXISTS}" ]]; then
    NAME_AVAILABLE=$(az storage account check-name \
        --name "${AZURE_STORAGE_ACCOUNT_NAME}" \
        --query nameAvailable -o tsv)

    # Fail if the name is already occupied globally by another account
    if [[ "${NAME_AVAILABLE}" != "true" ]]; then
        log_error "Storage account name is taken globally: ${AZURE_STORAGE_ACCOUNT_NAME}"
        exit 1
    fi

    # Create secure Azure Storage Account with production security controls
    az storage account create  \
    --name "${AZURE_STORAGE_ACCOUNT_NAME}" \
    --resource-group "${AZ_GROUP_NAME}" \
    --access-tier Hot \
    --allow-blob-public-access false \
    --allow-cross-tenant-replication false \
    --allow-shared-key-access false \
    --bypass None \
    --default-action Deny \
    --https-only true \
    --kind StorageV2 \
    --location "${AZURE_LOCATION}" \
    --min-tls-version TLS1_2 \
    --public-network-access Enabled \
    --require-infrastructure-encryption true \
    --sku Standard_LRS \
    --tags "${AZ_RESOURCE_TAGS[@]}" \
    -o none
else
    log_info "Storage account already exists, skipping: ${AZURE_STORAGE_ACCOUNT_NAME}"
fi