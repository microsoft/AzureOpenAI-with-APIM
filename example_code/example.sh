#!/bin/bash
apimUrl="apim_url"
deploymentName="deployment_name"
apiVersion="2024-02-15-preview"
subscriptionKey="subscription_key"

# URL, headers, and payload
url="${apimUrl}/deployments/${deploymentName}/chat/completions?api-version=${apiVersion}"
key="Ocp-Apim-Subscription-Key: ${subscriptionKey}"

# Properly structured JSON payload
jsonPayload='{
    "messages": [
        {
            "role": "system",
            "content": "You are an AI assistant that helps people find information."
        },
        {
            "role": "user",
            "content": "What are the differences between Azure Machine Learning and Azure AI services?"
        }
    ],
    "temperature": 0.7,
    "top_p": 0.95,
    "max_tokens": 800
}'

curl "${url}" -H "Content-Type: application/json" -H "${key}" -d "${jsonPayload}"
