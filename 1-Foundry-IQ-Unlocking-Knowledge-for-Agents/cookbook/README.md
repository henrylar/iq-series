# Episode 1 Cookbook: Unlocking Knowledge for your Agents

This folder contains the hands-on cookbook for Episode 1 of The IQ Series.

## 📋 Prerequisites

- **Azure Subscription** with permissions to create resources and assign roles
- **Azure CLI** installed and configured ([Install guide](https://learn.microsoft.com/cli/azure/install-azure-cli))
- **Python 3.10+** installed
- A region that supports [agentic retrieval](https://learn.microsoft.com/azure/search/search-region-support) (default: `eastus2`)

## 🚀 Deploy Azure Resources

> **Note:** This deployment is shared across all Foundry IQ episodes. You only need to deploy once — if you've already deployed for another episode, skip this step and reuse your existing resources.

Deploy all required Azure resources with one click — this creates AI Search, Azure OpenAI, AI Services, a Foundry project, an AI Search connection, Azure Blob Storage, model deployments, and RBAC roles:

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fhenrylar%2Fiq-series%2Fmain%2Finfra%2Fazuredeploy.json)

Tip: Use a short Resource Prefix like `iqser` to avoid Storage account name limits.

> **⚠️ Troubleshooting: Deployment script failed?**
>
> **Model Quota or Capacity Errors (April 2026):** If your deployment fails with `ServiceModelDeprecated` (for `gpt-4o-mini`), `InsufficientResourcesAvailable`, or `InsufficientQuota`, this is due to ongoing Azure OpenAI model transitions and high demand in US regions. 
> - **Workaround Example:** In our testing (April 2026), we bypassed this by changing the deployment region to a less saturated one (e.g., `eastus2`) and changing the Chat Model Name in the parameters to `gpt-4o` to fit within our available limits. Your exact workaround will depend on your subscription's active quota limits.
>
> **Storage account name length (name too long / invalid):** Azure Storage account names must be 3–24 lowercase alphanumeric characters. This template derives the storage account name as `<resourcePrefix> + 'stor' + <13-char unique suffix>`. If your `resourcePrefix` is long (for example, `iqseries`), the final name can exceed 24 characters and the deployment will fail.
> - **Symptom:** Errors like "The storage account name is invalid or exceeds 24 characters" during deployment.
> - **Fix:** Shorten `Resource Prefix` to 5 characters or fewer (for example, `iqser`) in the Portal parameter, or pass `-p iqser` to `infra/deploy.sh`, or set `-ResourcePrefix "iqser"` in `infra/deploy.ps1`.
> - **Why this works:** Using a 5-character prefix ensures `prefix + 'stor' + 13` stays within the 24-character limit.
>
> **Storage Access Errors:** Some Azure tenants enforce policies that block key-based access on storage accounts. This can cause the **data seeding script** to fail while all other resources deploy successfully. If this happens, your Azure resources are fully deployed — only the sample data and knowledge base setup is missing. You can seed the data manually using either of these alternatives:
>
> 1. **Run this cookbook**: Run this notebook end-to-end — it indexes the same NASA "Earth at Night" sample data to your AI Search and creates the knowledge source and knowledge base.
> 2. **Seed via Foundry IQ UI**: Create an index in AI Search manually using the [NASA Earth at Night dataset](https://raw.githubusercontent.com/Azure-Samples/azure-search-sample-data/main/nasa-e-book/earth-at-night-json/documents.json), then create a knowledge source and knowledge base pointing to it through the Foundry IQ portal.

In the deployment form:

- **Create a new resource group** (e.g., `iq-series-rg`) — click **Create new** under the Resource group field. If you've already created one for a previous episode, select it instead
- Enter your **User Object ID** (see below)
- Customize the resource prefix, location, and SKUs

**How to get your User Object ID:** Open a terminal and run:

```bash
az ad signed-in-user show --query id -o tsv
```

This returns your Microsoft Entra ID unique identifier — paste it into the deployment form. It's needed to assign proper RBAC roles to your account.

After deployment, create a `.env` file **in this folder** (`1-Foundry-IQ-Unlocking-Knowledge-for-Agents/cookbook/.env`) with your values from the deployment outputs:

```env
SEARCH_ENDPOINT=https://<your-search-service>.search.windows.net
AOAI_ENDPOINT=https://<your-openai-resource>.openai.azure.com
AOAI_EMBEDDING_MODEL=text-embedding-3-large
AOAI_EMBEDDING_DEPLOYMENT=text-embedding-3-large
AOAI_GPT_MODEL=gpt-4o
AOAI_GPT_DEPLOYMENT=gpt-4o
FOUNDRY_PROJECT_ENDPOINT=https://<your-ai-services>.services.ai.azure.com/api/projects/<your-project>
FOUNDRY_MODEL_DEPLOYMENT_NAME=gpt-4o
AZURE_AI_SEARCH_CONNECTION_NAME=iq-series-search-connection
FOUNDRY_PROJECT_RESOURCE_ID=/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.MachineLearningServices/workspaces/<workspace>/projects/<project>
```

**Where to find these values:** All values except `FOUNDRY_PROJECT_RESOURCE_ID` are available in the deployment **Outputs** tab in the Azure portal. To find the project resource ID, go to [Microsoft Foundry](https://ai.azure.com) → your project → **Overview** → **Properties** and copy the full ARM resource ID.

For CLI deployment and cleanup instructions, see the [Infrastructure Guide](../../infra/README.md).

## 📓 Cookbook Notebook

The [**Foundry IQ Cookbook**](./foundry-iq-cookbook.ipynb) walks you through Foundry IQ end-to-end, step by step:

1. Creating a knowledge source backed by an Azure AI Search index
2. Creating a knowledge base that pairs your data with an LLM for agentic retrieval
3. Querying the knowledge base and inspecting synthesized answers with citations
4. Connecting Foundry IQ to the Foundry Agent Service so an agent can ground its responses in your data

### Quick Start

1. Install dependencies: `pip install -U azure-search-documents==11.7.0b2 azure-ai-projects azure-identity python-dotenv`
2. Sign in to Azure: run `az login` in a terminal
3. Create a `.env` file with your endpoint values (see above)
4. Open `foundry-iq-cookbook.ipynb` in VS Code and run the cells

> **Running in GitHub Codespaces?** The devcontainer already installs all dependencies and the VS Code Jupyter extension automatically. Just open the `.ipynb` file directly in the VS Code editor — no need to install or launch a standalone Jupyter server. The notebook renders and runs natively inside VS Code.

## Additional Resources

- [Episode 1 README](../README.md)
- [Microsoft Foundry Documentation](https://learn.microsoft.com/azure/ai-foundry/)
- [Agentic Retrieval Quickstart](https://learn.microsoft.com/azure/search/search-get-started-agentic-retrieval)
