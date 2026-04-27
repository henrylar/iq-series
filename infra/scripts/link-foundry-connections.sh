#!/usr/bin/env bash
set -euo pipefail

# ======================================================
# Link Ep2/Ep3 Search to Ep1 Foundry (AI Services) Project
# - Adds/updates Foundry "CognitiveSearch" connections in the Ep1 project
# - Grants the Ep1 project managed identity RBAC on Ep2/Ep3 Search
# - Prints the Foundry project endpoint to paste into Ep2/Ep3 .env
#
# SAFE/IDEMPOTENT: No redeploys. Re-running will upsert connections.
#
# Requirements:
# - az CLI logged in (az login)
# - Sufficient permissions to read resources, create role assignments, and PUT connections
# ======================================================

# Fixed inputs (your resource group names)
EP1_AI_RG="rg-henrylar-iq-ep1-knowledge-sc"
EP2_RG="rg-henrylar-iq-ep2-knowledge-sc"
EP3_RG="rg-henrylar-iq-ep3-knowledge-sc"

# Assumed from templates
RESOURCE_PREFIX="iqser"
PROJECT_NAME="${RESOURCE_PREFIX}-project"

# Optional overrides (leave blank to auto-detect if unique)
# Export these before running if you need to disambiguate
#   export EP1_AI_NAME=iqser-ai-5utiibsbf53eo
#   export EP2_SEARCH_NAME=<your-ep2-search>
#   export EP3_SEARCH_NAME=<your-ep3-search>
EP1_AI_NAME="${EP1_AI_NAME:-}"
EP2_SEARCH_NAME="${EP2_SEARCH_NAME:-}"
EP3_SEARCH_NAME="${EP3_SEARCH_NAME:-}"

# Role to grant on the target Search services for the Ep1 project identity
# Default is read-only; set ROLE="Search Index Data Contributor" if you will write indexes
ROLE="${ROLE:-Search Index Data Reader}"

req() { command -v "$1" >/dev/null 2>&1 || { echo "Missing $1"; exit 1; }; }
req az

# Ensure logged in
az account show >/dev/null 2>&1 || { echo "Not logged in. Run: az login"; exit 1; }

# Detect Ep1 AI Services (Foundry) if not provided
if [[ -z "${EP1_AI_NAME}" ]]; then
  echo "Detecting Ep1 AI Services in RG: ${EP1_AI_RG}..."
  EP1_AI_NAME=$(az cognitiveservices account list -g "${EP1_AI_RG}" \
    --query "[?kind=='AIServices'].name | [0]" -o tsv)
  if [[ -z "${EP1_AI_NAME}" ]]; then
    echo "Could not auto-detect Ep1 AI Services. Set EP1_AI_NAME explicitly." >&2
    exit 1
  fi
fi

echo "Ep1 AI Services: ${EP1_AI_NAME}"
EP1_AI_ID=$(az cognitiveservices account show -g "${EP1_AI_RG}" -n "${EP1_AI_NAME}" --query id -o tsv)

# Resolve the Ep1 project identity (SystemAssigned)
PROJECT_RES_ID="${EP1_AI_ID}/projects/${PROJECT_NAME}"
PROJECT_IDENTITY=$(az resource show --ids "${PROJECT_RES_ID}" --query identity.principalId -o tsv)
if [[ -z "${PROJECT_IDENTITY}" ]]; then
  echo "Failed to read Ep1 project identity. Ensure the project exists and has SystemAssigned identity." >&2
  exit 1
fi

detect_search_name() {
  local rg="$1"
  local name
  name=$(az resource list -g "$rg" --resource-type "Microsoft.Search/searchServices" --query "[].name" -o tsv | head -n1)
  echo "$name"
}

resolve_search() {
  local rg="$1" name="$2" resolved
  if [[ -z "$name" ]]; then
    echo "Detecting Search service in RG: $rg..."
    name=$(detect_search_name "$rg")
    if [[ -z "$name" ]]; then
      echo "No Search service found in $rg. Set EP2_SEARCH_NAME/EP3_SEARCH_NAME." >&2
      exit 1
    fi
  fi
  resolved="$name"
  local id url
  id=$(az resource show -g "$rg" -n "$resolved" --resource-type "Microsoft.Search/searchServices" --query id -o tsv)
  url="https://${resolved}.search.windows.net"
  echo "$resolved|$id|$url"
}

link_search() {
  local rg="$1" name="$2" conn="$3"
  IFS="|" read -r searchName searchId targetUrl < <(resolve_search "$rg" "$name")
  echo "Linking $searchName ($rg) as $conn..."

  # Upsert Foundry connection in Ep1 project to the target Search
  az rest --method put \
    --url "https://management.azure.com${PROJECT_RES_ID}/connections/${conn}?api-version=2025-06-01" \
    --body @- <<EOF >/dev/null
{
  "properties": {
    "category": "CognitiveSearch",
    "authType": "AAD",
    "target": "${targetUrl}",
    "isSharedToAll": true,
    "metadata": { "ApiType": "Azure", "ResourceId": "${searchId}" }
  }
}
EOF

  # Grant RBAC to the Ep1 project identity on the target Search service
  az role assignment create --assignee "${PROJECT_IDENTITY}" \
    --role "${ROLE}" --scope "${searchId}" >/dev/null || true

  echo "Linked ${searchName} -> ${PROJECT_NAME} as ${conn} (role: ${ROLE})"
}

# Give distinct connection names to avoid collisions
EP2_CONNECTION_NAME="iq-series-search-connection-ep2"
EP3_CONNECTION_NAME="iq-series-search-connection-ep3"

link_search "${EP2_RG}" "${EP2_SEARCH_NAME}" "${EP2_CONNECTION_NAME}"
link_search "${EP3_RG}" "${EP3_SEARCH_NAME}" "${EP3_CONNECTION_NAME}"

echo ""
echo "Current connections in project:"
az rest --method get \
  --url "https://management.azure.com${PROJECT_RES_ID}/connections?api-version=2025-06-01" -o table || true

echo ""
echo "FOUNDRY_PROJECT_ENDPOINT=https://${EP1_AI_NAME}.services.ai.azure.com/api/projects/${PROJECT_NAME}"
echo "Paste that into Ep2/Ep3 .env"
