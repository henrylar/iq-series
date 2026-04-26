#!/bin/bash
USER_OID="96621d99-f0bc-4a72-b76a-836eb9c72673"
RG_NAME="rg-henrylar-iq-ep1-knowledge-sc"

# Fetch the existing OpenAI account name
OPENAI_ACCOUNT=$(az cognitiveservices account list -g $RG_NAME --query "[?kind=='OpenAI'].name | [0]" -o tsv)

if [ -z "$OPENAI_ACCOUNT" ]; then
    echo "Error: Could not find OpenAI account in resource group $RG_NAME."
    exit 1
fi

echo "Found OpenAI account: $OPENAI_ACCOUNT"
echo "Deploying gpt-4o (2024-11-20) with 20K TPM..."

az cognitiveservices account deployment create \
  -g "$RG_NAME" \
  -n "$OPENAI_ACCOUNT" \
  --deployment-name "gpt-4o" \
  --model-name "gpt-4o" \
  --model-version "2024-11-20" \
  --model-format "OpenAI" \
  --sku-name "Standard" \
  --sku-capacity 20
  
echo "Deployment command completed."
