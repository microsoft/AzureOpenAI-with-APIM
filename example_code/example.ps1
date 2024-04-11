# Update these values to match your environment
$apimUrl = 'apim_url'
$deploymentName = 'deployment_name'
$apiVersion = '2024-02-15-preview'
$subscriptionKey = 'subscription_key'


# Construct the URL
$url = "$apimUrl/deployments/$deploymentName/chat/completions?api-version=$apiVersion"

# Headers
$headers = @{
    "Content-Type" = "application/json"
    "Ocp-Apim-Subscription-Key" = $subscriptionKey
}

# JSON Body
$body = @{
    messages = @(
        @{
            role = "system"
            content = "You are an AI assistant that helps people find information."
        },
        @{
            role = "user"
            content = "What are the differences between Azure Machine Learning and Azure AI services?"
        }
    )
    temperature = 0.7
    top_p = 0.95
    max_tokens = 800
} | ConvertTo-Json

# Invoke the API
$response = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body

# Output the response
$response.choices.message.content
