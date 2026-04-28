# Deploy to Your Own Azure Subscription

This folder contains the infrastructure-as-code to deploy all Azure resources needed for The IQ Series cookbooks.

## One-Click Deploy

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fhenrylar%2Fiq-series%2Fmain%2Finfra%2Fazuredeploy.json)

Click the button above to deploy directly from the Azure Portal. You'll be prompted for:
- **User Object ID** — run `az ad signed-in-user show --query id -o tsv` to get yours
- **Resource Prefix** — a short name prefix for all resources (default: `iqser`; tip: keep to 5 characters or fewer to avoid Storage account name length limits)
- **Location** — Azure region (must support [agentic retrieval](https://learn.microsoft.com/azure/search/search-region-support))

> **⚠️ Troubleshooting: Deployment script failed?**
>
> **Model Quota or Capacity Errors (April 2026):** If your deployment fails with `ServiceModelDeprecated` (for `gpt-4o-mini`), `InsufficientResourcesAvailable`, or `InsufficientQuota`, this is due to ongoing Azure OpenAI model transitions and high demand in US regions. 
> - **Workaround Example:** In our testing (April 2026), we bypassed this by changing the deployment region to a less saturated one (e.g., `eastus2`) and changing the Chat Model Name in the parameters to `gpt-4o` to fit within our available limits. Your exact workaround will depend on your subscription's active quota limits.
>
> **Storage account name length (name too long / invalid):** Azure Storage account names must be 3–24 lowercase alphanumeric characters. This template derives the storage account name as `<resourcePrefix> + 'stor' + <13-char unique suffix>`. If your `resourcePrefix` is long (for example, `iqseries`), the final name can exceed 24 characters and the deployment will fail.
> - **Symptom:** Errors like "The storage account name is invalid or exceeds 24 characters" during deployment.
> - **Fix:** Shorten `Resource Prefix` to 5 characters or fewer (for example, `iqser`) in the Portal parameter, or pass `-p iqser` to `deploy.sh`, or set `ResourcePrefix "iqser"` in `deploy.ps1`.
> - **Why this works:** Using a 5-character prefix ensures `prefix + 'stor' + 13` stays within the 24-character limit.
>
> **Storage Access Errors:** Some Azure tenants enforce policies that block key-based access on storage accounts. This can cause the **data seeding script** to fail while all other resources deploy successfully. If this happens, your Azure resources are fully deployed — only the sample data and knowledge base setup is missing. You can seed the data manually using either of these alternatives:
>
> 1. **Run the Episode 1 cookbook**: Open the [Episode 1 cookbook](../1-Foundry-IQ-Unlocking-Knowledge-for-Agents/cookbook/) and run it end-to-end — it indexes the same NASA "Earth at Night" data and creates the knowledge source and knowledge base.
> 2. **Seed via Foundry IQ UI**: Create an index in AI Search manually using the [NASA Earth at Night dataset](https://raw.githubusercontent.com/Azure-Samples/azure-search-sample-data/main/nasa-e-book/earth-at-night-json/documents.json), then create a knowledge source and knowledge base pointing to it through the Foundry IQ portal.

After deployment, copy the output values from the portal and create a `.env` file **inside each episode's `cookbook/` folder** (e.g., `1-Foundry-IQ-Unlocking-Knowledge-for-Agents/cookbook/.env`):

```
SEARCH_ENDPOINT=<searchEndpoint output>
AOAI_ENDPOINT=<openAiEndpoint output>
AOAI_EMBEDDING_MODEL=text-embedding-3-large
AOAI_EMBEDDING_DEPLOYMENT=text-embedding-3-large
AOAI_GPT_MODEL=gpt-5.4-mini
AOAI_GPT_DEPLOYMENT=gpt-5.4-mini
FOUNDRY_PROJECT_ENDPOINT=<foundryProjectEndpoint output>
FOUNDRY_MODEL_DEPLOYMENT_NAME=gpt-5.4-mini
AZURE_AI_SEARCH_CONNECTION_NAME=<searchConnectionName output>
```

## What Gets Deployed

| Resource | Purpose |
|----------|---------|
| **Azure AI Search** (Standard) | Vector search, semantic ranking, agentic retrieval |
| **Azure OpenAI** | `text-embedding-3-large` + `gpt-5.4-mini` model deployments |
| **Azure AI Services** | Foundry resource with project management enabled |
| **Foundry Project** | Project for running the IQ Series cookbooks |
| **AI Search Connection** | Connects the Foundry project to your AI Search service |
| **RBAC Role Assignments** | Proper permissions for your user + service-to-service access |

## 📋 Prerequisites

- **Azure Subscription** with permissions to create resources and assign roles
- **Azure CLI** installed and configured ([Install guide](https://learn.microsoft.com/cli/azure/install-azure-cli))
- **Python 3.10+** installed
- A region that supports [agentic retrieval](https://learn.microsoft.com/azure/search/search-region-support) (default: `eastus2`)

## 🚀 Quick Start

### 1. Login to Azure

```bash
az login
```

### 2. Deploy Infrastructure

⏱️ Estimated time: 5-10 minutes

**macOS / Linux:**

```bash
cd infra
./deploy.sh -g "iq-series-rg" -l "eastus2"
```

**Windows (PowerShell):**

```powershell
cd infra
.\deploy.ps1 -ResourceGroupName "iq-series-rg" -Location "eastus2"
```

This will:
- Create the resource group
- Deploy all Azure resources via Bicep
- Set up RBAC role assignments
- Generate a `.env` file in the repo root with all endpoints

### ✅ Pre-check storage account name length (optional)

Before deploying, you can validate that your `Resource Prefix` will produce a valid storage account name (≤ 24 chars).

Using Bash:

```bash
# Example: change PREFIX to your chosen resource prefix
PREFIX=iqser
UNIQUE_SUFFIX=$(az group show -n iq-series-rg --query id -o tsv | xargs -I {} az rest --method post --uri "https://management.azure.com{}/providers/Microsoft.Resources/calculateHash?api-version=2021-04-01" --body '{"properties": {"templateHash": "dummy"}}' 2>/dev/null | jq -r '.properties.templateHash' | cut -c1-13)
STORAGE_NAME="${PREFIX}stor${UNIQUE_SUFFIX}"
echo "Computed storage name: $STORAGE_NAME (len=${#STORAGE_NAME})"
if [ ${#STORAGE_NAME} -le 24 ]; then echo "OK"; else echo "Too long — shorten PREFIX"; fi
```

Using PowerShell:

```powershell
$prefix = "iqser"
$rg = "iq-series-rg" # or your target RG name (if not created yet, pick a placeholder)
$rgId = (az group show -n $rg --query id -o tsv)
$hash = az rest --method post --uri "https://management.azure.com$rgId/providers/Microsoft.Resources/calculateHash?api-version=2021-04-01" --body '{"properties": {"templateHash": "dummy"}}' | ConvertFrom-Json
$uniqueSuffix = $hash.properties.templateHash.Substring(0,13)
$storageName = "$prefix" + "stor" + $uniqueSuffix
Write-Host "Computed storage name: $storageName (len=$($storageName.Length))"
if ($storageName.Length -le 24) { Write-Host "OK" } else { Write-Host "Too long — shorten prefix" }
```

These approximate the template's `uniqueString(resourceGroup().id)`-based suffix with a deterministic 13-character string, letting you sanity-check name length ahead of time. If the length exceeds 24, reduce your `Resource Prefix` (for example, to `iqser`).

### 3. Run the Cookbooks

```bash
cd 1-Foundry-IQ-Unlocking-Knowledge-for-Agents/cookbook/
# Open foundry-iq-cookbook.ipynb in VS Code or Jupyter
```

The notebooks will automatically read from the `.env` file — no manual configuration needed.

## 🧹 Cleanup

Delete all resources to avoid ongoing charges:

```bash
az group delete --name iq-series-rg --yes --no-wait
```

## Reuse an existing Foundry/OpenAI (Ep2/Ep3)

If you've already deployed Episode 1 and want to deploy Episode 2 or 3 without creating additional Azure OpenAI or AI Services (Foundry) resources (e.g., due to quota), the template exposes toggles to skip those pieces and deploy only Search, Storage, RBAC, and outputs.

Toggles (all default `true` to preserve Ep1 behavior):

| Parameter | Effect when set to `false` |
|-----------|-----------------------------|
| `deployOpenAI` | Skip the Azure OpenAI account |
| `deployOpenAIDeployments` | Skip Azure OpenAI model deployments |
| `deployAIServices` | Skip the AI Services (Foundry) account |
| `deployFoundryProject` | Skip the Foundry project (requires `deployAIServices=false` or true) |
| `deployAIServicesDeployments` | Skip model deployments on the Foundry account |
| `deploySearchConnection` | Skip creating the project → Search connection |
| `seedData` | Skip the data seeding script (requires OpenAI to be present) |

Preset parameters file: `main.reuse-foundry.parameters.json`.

CLI (Ep2 or Ep3):

```bash
az deployment group create \
  -g rg-henrylar-iq-ep3-knowledge-sc \
  -f infra/azuredeploy.json \
  -p @infra/main.reuse-foundry.parameters.json \
  -p userObjectId=<your-object-id>
```

Portal ("Deploy to Azure"): set the above toggles to `false` in the parameters form (and `seedData=false`).

After deployment, link the new Search service to your existing Ep1 Foundry project using `infra/scripts/link-foundry-connections.sh`, then update the episode's `cookbook/.env` with the new `SEARCH_ENDPOINT` (and `BLOB_CONNECTION_STRING` / `BLOB_CONTAINER_NAME` for Ep2).

## 📁 Files

| File | Description |
|------|-------------|
| `main.bicep` | Bicep template defining all Azure resources |
| `main.parameters.json` | Default parameter values |
| `main.reuse-foundry.parameters.json` | Preset to skip OpenAI/Foundry for Ep2/Ep3 |
| `deploy.sh` | Deployment script for macOS/Linux |
| `deploy.ps1` | Deployment script for Windows PowerShell |
| `scripts/link-foundry-connections.sh` | Links new Search services to the Ep1 Foundry project |
