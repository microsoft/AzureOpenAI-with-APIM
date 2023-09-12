@description('The location into which regionally scoped resources should be deployed. Note that Front Door is a global resource.')
param location string = resourceGroup().location

@description('The SKU of the API Management instance.')
@allowed([
  'Premium'
  'Developer'
])
param apiManagementSku string = 'Premium'

@description('The name of the API publisher. This information is used by API Management.')
param apiManagementPublisherName string = 'Contoso'

@description('The email address of the API publisher. This information is used by API Management.')
param apiManagementPublisherEmail string = 'admin@contoso.com'

@description('Provide Key 1 for the Azure Open AI service.')
@secure()
param azureOpenAiKey string

@description('Provide the URL of the Azure Open AI service.')
param apiServiceUrl string = 'https://InsertYourAzureOpenAiNameHere.openai.azure.com/openai'

var openApiJson = 'https://raw.githubusercontent.com/paullizer/AzureOpenAI-with-APIM/main/AzureOpenAI_OpenAPI.json'
var openApiXml = 'https://raw.githubusercontent.com/paullizer/AzureOpenAI-with-APIM/main/AzureOpenAI_Policy.xml'

var tenantId = subscription().tenantId

var keyVaultskuName = 'standard'
var secretName = 'aoai-api-key'
var keysPermissions = ['list']
var secretsPermissions = ['list']
var enabledForDeployment = false
var enabledForDiskEncryption = false
var enabledForTemplateDeployment = false

var apiManagementSkuCount = 1
var apiManagementNamedValueName = 'aoai-api-key'

var apiName = 'azure-openai-service-api'
var apiPath = ''
var apiSubscriptionName = 'AzureOpenAI-Consumer-Example'

var apiManagementServiceName = 'apim-${uniqueString(resourceGroup().id)}'
var keyVaultName = 'kv-${uniqueString(resourceGroup().id)}'
var logAnalyticsName = 'law-${uniqueString(resourceGroup().id)}'
var applicationInsightsName = 'appIn-${uniqueString(resourceGroup().id)}'

module logAnalyticsWorkspace 'modules/log-analytics-workspace.bicep' = {
  name: 'log-analytics-workspace'
  params: {
    location: location
    logAnalyticsName: logAnalyticsName
    applicationInsightsName : applicationInsightsName
  }
}

module apiManagement 'modules/api-management.bicep' = {
  name: 'api-management'
  params: {
    location: location
    serviceName: apiManagementServiceName
    publisherName: apiManagementPublisherName
    publisherEmail: apiManagementPublisherEmail
    skuName: apiManagementSku
    skuCount: apiManagementSkuCount
  }
}

module keyVault 'modules/key-vault.bicep' = {
  name: 'key-vault'
  params: {
    location: location
    keyVaultName: keyVaultName
    enabledForDeployment: enabledForDeployment
    enabledForDiskEncryption: enabledForDiskEncryption
    enabledForTemplateDeployment: enabledForTemplateDeployment
    tenantId: tenantId
    objectId: apiManagement.outputs.apiManagementIdentityPrincipalId
    keysPermissions: keysPermissions
    secretsPermissions: secretsPermissions
    skuName: keyVaultskuName
    secretName: secretName
    secretValue: azureOpenAiKey
  }
  dependsOn: [
    apiManagement
  ]
}

resource apiManagementService 'Microsoft.ApiManagement/service@2021-08-01' existing = {
  name: apiManagementServiceName

  resource namedValue 'namedValues' = {
    name: apiManagementNamedValueName
    dependsOn: [
      apiManagement
      keyVault
    ]
    properties: {
      displayName: apiManagementNamedValueName
      value: azureOpenAiKey
      secret: true
    }
  }
}

module api 'modules/api.bicep' = {
  name: 'api'
  params: {
    apimName: apiManagementServiceName
    apiName: apiName
    apiPath: apiPath
    openApiJson : openApiJson
    openApiXml : openApiXml
    serviceUrl: apiServiceUrl
    apiSubscriptionName: apiSubscriptionName
  }
  dependsOn: [
    keyVault
    apiManagementService
  ]
}

output apiManagementProxyHostName string = apiManagement.outputs.apiManagementProxyHostName
output apiManagementPortalHostName string = apiManagement.outputs.apiManagementDeveloperPortalHostName
