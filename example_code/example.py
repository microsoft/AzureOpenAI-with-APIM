# This code is an example of how to use the OpenAI API with Azure API Management (APIM) in a Jupyter Notebook.
import requests
import json

# Set the parameters
apim_url = "apim_url"
deployment_name = "deployment_name"
api_version = "2024-02-15-preview"
subscription_key = "subscription_key"

# Construct the URL and headers
url = f"{apim_url}/deployments/{deployment_name}/chat/completions?api-version={api_version}"
headers = {
    "Content-Type": "application/json",
    "Ocp-Apim-Subscription-Key": subscription_key
}

# Define the JSON payload
json_payload = {
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
}

# Make the POST request
response = requests.post(url, headers=headers, json=json_payload)

# Print the response text (or you can process it further as needed)
print(response.text)