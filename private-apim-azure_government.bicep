@description('The location into which regionally scoped resources should be deployed. Note that Front Door is a global resource.')
param location string = resourceGroup().location

@description('The IP address prefix (CIDR range) to use when deploying the virtual network.')
param vnetIPPrefix string = '10.0.0.0/16'

@description('The SKU of the API Management instance.')
@allowed([
  'Premium'
  'Developer'
])
param apiManagementSku string = 'Premium'

@description('The IP address prefix (CIDR range) to use when deploying the API Management subnet within the virtual network.')
param apiManagementSubnetIPPrefix string = '10.0.0.0/24'

@description('The name of the API publisher. This information is used by API Management.')
param apiManagementPublisherName string = 'Contoso'

@description('The email address of the API publisher. This information is used by API Management.')
param apiManagementPublisherEmail string = 'admin@contoso.com'

@description('Provide Key 1 for the Azure Open AI service.')
@secure()
param azureOpenAiKey string

@description('Provide the URL of the Azure Open AI service.')
param apiServiceUrl string = 'https://InsertYourAzureOpenAiNameHere.openai.azure.com/openai'

@description('Provide the Public IP address of the Azure Open AI service.')
param azureOpenAiPublicIpAddress string = '000.000.000.000'

var openApiJson = 'https://raw.githubusercontent.com/microsoft/AzureOpenAI-with-APIM/main/AzureOpenAI_OpenAPI.json'
var openApiXml = 'https://raw.githubusercontent.com/microsoft/AzureOpenAI-with-APIM/main/AzureOpenAI_Policy.xml'

var tenantId = subscription().tenantId

var apiNetwork = 'Internal'

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

var vnetName = 'vNet-${uniqueString(resourceGroup().id)}'
// var privateEndpointName = 'pe-${uniqueString(resourceGroup().id)}'
var apiManagementServiceName = 'apim-${uniqueString(resourceGroup().id)}'
var keyVaultName = 'kv-${uniqueString(resourceGroup().id)}'
var logAnalyticsName = 'law-${uniqueString(resourceGroup().id)}'
var applicationInsightsName = 'appIn-${uniqueString(resourceGroup().id)}'
var routeTableName = 'rt-${uniqueString(resourceGroup().id)}'

var privateDnsZoneNameApim = 'azure-api.us'
var privateDnsZoneNameAzureOpenAi = 'openai.azure.com'

module logAnalyticsWorkspace 'modules/log-analytics-workspace.bicep' = {
  name: 'log-analytics-workspace'
  params: {
    location: location
    logAnalyticsName: logAnalyticsName
    applicationInsightsName : applicationInsightsName
  }
}

module network 'modules/network.bicep' = {
  name: 'network'
  params: {
    vnetName: vnetName
    location: location
    vnetIPPrefix: vnetIPPrefix
    apiManagementSubnetIPPrefix: apiManagementSubnetIPPrefix
  }
  dependsOn: [
    logAnalyticsWorkspace
  ]
}

module apiManagement 'modules/api-management-private.bicep' = {
  name: 'api-management'
  params: {
    location: location
    serviceName: apiManagementServiceName
    publisherName: apiManagementPublisherName
    publisherEmail: apiManagementPublisherEmail
    skuName: apiManagementSku
    skuCount: apiManagementSkuCount
    subnetResourceId: network.outputs.apiManagementSubnetResourceId
    virtualNetworkType: apiNetwork
  }
  dependsOn: [
    network
  ]
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

module privateDnsZoneApim 'modules/private-dns-zone-apim.bicep' = {
  name: 'private-dns-zone-apim'
  params: {
    privateDnsZoneName: privateDnsZoneNameApim
    apimName: apiManagementServiceName
    vnetName: vnetName
  }
  dependsOn: [
    apiManagement
  ]
}

module privateDnsZoneAzureOpenAi 'modules/private-dns-zone-aoai.bicep' = {
  name: 'private-dns-zone-aoai'
  params: {
    privateDnsZoneName: privateDnsZoneNameAzureOpenAi
    apiServiceUrl: apiServiceUrl
    azureOpenAiPublicIpAddress: azureOpenAiPublicIpAddress
    vnetName: vnetName
  }
  dependsOn: [
    privateDnsZoneApim
  ]
}

module routeTable 'modules/route-table.bicep' = {
  name: 'route-table'
  params: {
    routeTableName: routeTableName
    location: location
    azureOpenAiPublicIpAddress: azureOpenAiPublicIpAddress
  }

}


output apiManagementProxyHostName string = apiManagement.outputs.apiManagementProxyHostName
output apiManagementPortalHostName string = apiManagement.outputs.apiManagementDeveloperPortalHostName
