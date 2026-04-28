import requests
from azure.identity import get_bearer_token_provider, AzureCliCredential

# Get token for management API
credential = AzureCliCredential()
token_provider = get_bearer_token_provider(credential, "https://management.azure.com/.default")

token = token_provider()

# Update connection to be shared
url = "https://management.azure.com/subscriptions/8351c640-0045-436a-9ba8-2da7543a6192/resourceGroups/rg-henrylar-iq-ep1-knowledge-eastus2/providers/Microsoft.CognitiveServices/accounts/iqser-ai-wbmuq7qfehhz2/projects/iqser-project/connections/earth-kb-mcp-connection?api-version=2025-10-01-preview"

headers = {
    "Authorization": f"Bearer {token}",
    "Content-Type": "application/json"
}

body = {
    "properties": {
        "authType": "ProjectManagedIdentity",
        "category": "RemoteTool",
        "target": "https://iqser-search-wbmuq7qfehhz2.search.windows.net/knowledgebases/earth-knowledge-base/mcp?api-version=2025-11-01-Preview",
        "isSharedToAll": True,
        "audience": "https://search.azure.com/",
        "metadata": {"ApiType": "Azure"}
    }
}

response = requests.put(url, headers=headers, json=body)
print(f"Status: {response.status_code}")
print(response.json())
