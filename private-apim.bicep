@description('The location into which regionally scoped resources should be deployed. Note that Front Door is a global resource.')
param location string = resourceGroup().location

@description('The IP address prefix (CIDR range) to use when deploying the virtual network.')
param vnetIPPrefix string = '10.0.0.0/16'

@description('The SKU of the API Management instance.')
@allowed([
  'Premium'
  'Developer'
  'BasicV2'
  'StandardV2'
])
param apiManagementSku string = 'Developer'

@description('The IP address prefix (CIDR range) to use when deploying the API Management subnet within the virtual network.')
param apiManagementSubnetIPPrefix string = '10.0.0.0/24'

@description('The name of the API publisher. This information is used by API Management.')
param apiManagementPublisherName string = 'Contoso'

@description('The email address of the API publisher. This information is used by API Management.')
param apiManagementPublisherEmail string = 'admin@contoso.com'


@description('Provide the Name of the Azure Open AI service.')
param apiServiceNamePrimary string = 'Insert_Your_Azure_OpenAi_Name_Here'

@description('Provide the Resource Group Name of the Azure Open AI service.')
param apiServiceRgPrimary string = 'Insert_Resource_Group_Name_Here'

@description('If you want to provide resiliency when single region exceeds quota, then select Multi and provide URL to an additional Azure OpenAI endpoint. Otherwise, maintain default entry of Single and only provide one Azure OpenAI endpoint.')
@allowed([
  'Single'
  'Multi'
])
param azureOpenAiRegionType string = 'Single'

@description('If you select Multi in azureOpenAiRegionType, then you must provide another Azure OpenAI Name here.')
param apiServiceNameSecondary string = 'Maybe-Insert_Your_Secondary_Azure_OpenAi_Name_Here'

@description('If you select Multi in azureOpenAiRegionType, provide the Resource Group Name of the Azure Open AI service.')
param apiServiceRgSecondary string = 'Maybe-Insert_Resource_Group_Name_Here'

@description('If you want to enable retry policy for the API, set this to true. Otherwise, set this to false.')
param enableRetryPolicy bool = false

var apiServiceUrlPrimary = 'https://${apiServiceNamePrimary}.openai.azure.com/openai'
var apiServiceUrlSecondary = 'https://${apiServiceNameSecondary}.openai.azure.com/openai'

// The following logic is used to determine the OpenAPI XML policy file to use based on the region type and retry policy setting.
var openApiXmlRetry = enableRetryPolicy ? 'https://raw.githubusercontent.com/microsoft/AzureOpenAI-with-APIM/main/apim_policies/AOAI_Policy-Managed_Identity_with_Retry_SingleRegion.xml' : 'https://raw.githubusercontent.com/microsoft/AzureOpenAI-with-APIM/main/apim_policies/AOAI_Policy-Managed_Identity.xml'
var openApiXml = azureOpenAiRegionType == 'Multi' ? 'https://raw.githubusercontent.com/microsoft/AzureOpenAI-with-APIM/main/apim_policies/AOAI_Policy-Managed_Identity_with_Retry_MultiRegion.xml' : openApiXmlRetry

var openApiJson = 'https://raw.githubusercontent.com/microsoft/AzureOpenAI-with-APIM/main/api_definitions/AzureOpenAI_OpenAPI.json'

var apiNetwork = 'Internal'

var apiManagementSkuCount = 1

var apiName = 'azure-openai-service-api'
var apiPath = ''
var apiSubscriptionName = 'AzureOpenAI-Consumer-Chat'

var unique = uniqueString(resourceGroup().id, subscription().id)
var vnetName = 'vNet-${unique}'
var apiManagementServiceName = 'apim-${unique}'
var logAnalyticsName = 'law-${unique}'
var eventHubName = 'eh-${unique}'
var eventHubNamespaceName = 'ehn-${unique}'
var applicationInsightsName = 'appIn-${unique}'
var privateDnsZoneName = 'azure-api.net'

var azureRoles = loadJsonContent('azure_roles.json')

module logAnalyticsWorkspace 'modules/log-analytics-workspace.bicep' = {
  name: 'log-analytics-workspace'
  params: {
    location: location
    logAnalyticsName: logAnalyticsName
  }
}

module eventHub 'modules/event-hub.bicep' = {
  name: 'event-hub'
  params: {
    location: location
    eventHubNamespaceName: eventHubNamespaceName
    eventHubName: eventHubName
  }
}

module applicationInsights 'modules/app-insights.bicep' = {
  name: 'application-insights'
  params: {
    location: location
    workspaceName: logAnalyticsName
    applicationInsightsName: applicationInsightsName
  }
  dependsOn: [
    logAnalyticsWorkspace
  ]
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
    aiName: applicationInsightsName
    eventHubName: eventHubName
    eventHubNamespaceName: eventHubNamespaceName
  }
  dependsOn: [
    network
    applicationInsights
    eventHub
    logAnalyticsWorkspace
  ]
}

module api 'modules/api.bicep' = {
  name: 'api'
  params: {
    apimName: apiManagementServiceName
    apiName: apiName
    apiPath: apiPath
    openApiJson : openApiJson
    openApiXml : openApiXml
    serviceUrlPrimary : apiServiceUrlPrimary
    serviceUrlSecondary: apiServiceUrlSecondary
    azureOpenAiRegionType: azureOpenAiRegionType
    apiSubscriptionName: apiSubscriptionName
    aiLoggerId: apiManagement.outputs.aiLoggerId
  }
  dependsOn: [
    apiManagement
  ]
}

module privateDnsZone 'modules/private-dns-zone-apim.bicep' = {
  name: 'private-dns-zone'
  params: {
    privateDnsZoneName: privateDnsZoneName
    apimName: apiManagementServiceName
    vnetName: vnetName
  }
  dependsOn: [
    apiManagement
  ]
}

resource eventHubNamespaceParent 'Microsoft.EventHub/namespaces@2021-01-01-preview' existing = {
  name: eventHubNamespaceName
}

resource azureEventHubsDataSender 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, resourceGroup().id, eventHubNamespaceName)
  scope: eventHubNamespaceParent
  properties: {
    principalId: apiManagement.outputs.apiManagementIdentityPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', azureRoles.AzureEventHubsDataSender)
  }
  dependsOn: [
    apiManagement
  ]
}

module openAiUserPrimary 'modules/role.bicep' = {
  name: 'openAiUserPrimary'
  scope: resourceGroup(apiServiceRgPrimary)
  params: {
    roleName: guid(subscription().id, resourceGroup().id, eventHubNamespaceName, 'Primary')
    principalId: apiManagement.outputs.apiManagementIdentityPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', azureRoles.CognitiveServicesOpenAIUser)
  }
  dependsOn: [
    apiManagement
  ]
}

module openAiUserSecondary 'modules/role.bicep' = {
  name: 'openAiUserSecondary'
  scope: resourceGroup(apiServiceRgSecondary)
  params: {
    roleName: guid(subscription().id, resourceGroup().id, eventHubNamespaceName, 'Primary')
    principalId: apiManagement.outputs.apiManagementIdentityPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', azureRoles.CognitiveServicesOpenAIUser)
  }
  dependsOn: [
    apiManagement
  ]
}

output apiManagementProxyHostName string = apiManagement.outputs.apiManagementProxyHostName
output apiManagementPortalHostName string = apiManagement.outputs.apiManagementDeveloperPortalHostName
