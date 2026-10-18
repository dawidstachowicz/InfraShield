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

# Check if the Storage Account already exists in the target Resource Group
AZ_STORAGE_ACCOUNT_EXISTS=$(az storage account list \
    --resource-group "${AZ_GROUP_NAME}" \
    --query "[?name=='${AZURE_STORAGE_ACCOUNT_NAME}'].name" \
    -o tsv)

# Create Storage Account if it does not exist in the Resource Group
if [[ -z "${AZ_STORAGE_ACCOUNT_EXISTS}" ]]; then

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

# Initialize array to store target IP addresses or CIDR ranges for firewall rules
IP_LIST=()

# Parse comma-separated IP addresses or CIDR ranges from ALLOWED_PUBLIC_IPS after stripping whitespace
if [[ -n "${ALLOWED_PUBLIC_IPS}" ]]; then
    IFS=',' read -ra IP_LIST <<< "${ALLOWED_PUBLIC_IPS// /}"
fi

# Automatically detect current external IPv4 address if enabled
if [[ "${AUTO_DETECT_PUBLIC_IP}" == "true" ]]; then
    IP_LIST+=("$(curl -4 -fsS --max-time 10 ifconfig.me)")
fi

# Apply network firewall rules in bulk if any IP addresses were collected
if [[ ${#IP_LIST[@]} -gt 0 ]]; then
    az storage account network-rule add \
        --resource-group "${AZ_GROUP_NAME}" \
        --account-name "${AZURE_STORAGE_ACCOUNT_NAME}" \
        --ip-address "${IP_LIST[@]}" \
        -o none
fi

# Define target RBAC role for data-plane access to Azure Storage Blobs
ROLE_NAME="Storage Blob Data Contributor"

# Retrieve Object ID of currently authenticated Azure AD user
SIGNED_IN_USER_ID="$(az ad signed-in-user show --query id -o tsv)"

# Retrieve full Azure Resource ID for the target Storage Account
STORAGE_ACCOUNT_ID="$(az storage account show -n "${AZURE_STORAGE_ACCOUNT_NAME}" -g "${AZ_GROUP_NAME}" --query id -o tsv)"

# Check if the user already has the specified RBAC role assigned at the Storage Account scope
CHECK_EXISTING_ROLE=$(az role assignment list \
    --assignee "${SIGNED_IN_USER_ID}" \
    --scope "${STORAGE_ACCOUNT_ID}" \
    --query "[?roleDefinitionName=='${ROLE_NAME}'].roleDefinitionName" -o tsv)

# Assign the RBAC role if no existing assignment is found
if [[ -z "${CHECK_EXISTING_ROLE}" ]]; then
    az role assignment create \
        --assignee "${SIGNED_IN_USER_ID}" \
        --role "${ROLE_NAME}" \
        --scope "${STORAGE_ACCOUNT_ID}" \
        -o none
else
    log_info "Role assignment already exists, skipping: ${ROLE_NAME}"
fi

# Check if the target Blob container exists using Azure AD authentication
CHECK_CONTAINER_EXISTS=$(az storage container exists \
    --name "${AZURE_CONTAINER_NAME}" \
    --account-name "${AZURE_STORAGE_ACCOUNT_NAME}" \
    --auth-mode login \
    --query exists -o tsv)

# Create container if it does not already exist
if [[ "${CHECK_CONTAINER_EXISTS}" != true ]]; then
    # Create private Blob container for storing Terraform state files
    az storage container create --name "${AZURE_CONTAINER_NAME}" \
        --account-name "${AZURE_STORAGE_ACCOUNT_NAME}" \
        --auth-mode login \
        --public-access off \
        -o none
else
    # Log informational message if container is already present
    log_info "Container already exists, skipping: ${AZURE_CONTAINER_NAME}"
fi

log_info "Bootstrap complete: ${AZ_GROUP_NAME} / ${AZURE_STORAGE_ACCOUNT_NAME} / ${AZURE_CONTAINER_NAME}"