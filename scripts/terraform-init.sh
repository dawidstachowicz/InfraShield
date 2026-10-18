#!/usr/bin/env bash

# ==============================================================================
# Script Name: terraform-init.sh
# Description: Initialize Terraform backend using values from .env.
# ==============================================================================

# Strict mode: fail on error or unset vars
set -euo pipefail

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_SCRIPT="${SCRIPT_DIR}/_utils.sh"
PROJECT_DIR="${SCRIPT_DIR}/.."
ENV_FILE="${PROJECT_DIR}/.env"
TF_DIR="${PROJECT_DIR}/terraform"

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

# Build the same names the bootstrap creates
AZ_GROUP_NAME="rg-${PROJECT}-tfstate-${AZURE_LOCATION}-${RESOURCE_SEQUENCE}"

# Initialize backend: names come from .env, auth via Azure AD (no shared keys)
terraform -chdir="${TF_DIR}" init \
    -backend-config="resource_group_name=${AZ_GROUP_NAME}" \
    -backend-config="storage_account_name=${AZURE_STORAGE_ACCOUNT_NAME}" \
    -backend-config="container_name=${AZURE_CONTAINER_NAME}" \
    -backend-config="key=${PROJECT}.${ENVIRONMENT}.tfstate"