@description('The location into which the API Management resources should be deployed.')
param location string

@description('The name of the API Management service instance to create. This must be globally unique.')
param serviceName string

@description('The name of the API publisher. This information is used by API Management.')
param publisherName string

@description('The email address of the API publisher. This information is used by API Management.')
param publisherEmail string

param aiName string

param eventHubNamespaceName string
param eventHubName string

@description('The name of the SKU to use when creating the API Management service instance. This must be a SKU that supports virtual network integration.')
param skuName string

@description('The number of worker instances of your API Management service that should be provisioned.')
param skuCount int

param virtualNetworkType string

param subnetResourceId string

resource aiParent 'Microsoft.Insights/components@2020-02-02-preview' existing = {
  name: aiName
}
resource apiManagementService 'Microsoft.ApiManagement/service@2023-03-01-preview' = {
  name: serviceName
  location: location
  sku: {
    name: skuName
    capacity: skuCount
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publisherName: publisherName
    publisherEmail: publisherEmail
    virtualNetworkConfiguration: {
      subnetResourceId: subnetResourceId
    }
    virtualNetworkType: virtualNetworkType
  }
}

resource aiLoggerWithSystemAssignedIdentity 'Microsoft.ApiManagement/service/loggers@2022-08-01' = {
  name: 'aiLoggerWithSystemAssignedIdentity'
  parent: apiManagementService
  properties: {
    loggerType: 'applicationInsights'
    description: 'Application Insights logger with connection string'
    credentials: {
      connectionString: aiParent.properties.ConnectionString
      identityClientId: 'systemAssigned'
    }
  }
}

output apiManagementInternalIPAddress string = apiManagementService.properties.publicIPAddresses[0]
output apiManagementIdentityPrincipalId string = apiManagementService.identity.principalId
output apiManagementProxyHostName string = apiManagementService.properties.hostnameConfigurations[0].hostName
output apiManagementDeveloperPortalHostName string = replace(apiManagementService.properties.developerPortalUrl, 'https://', '')
output aiLoggerId string = aiLoggerWithSystemAssignedIdentity.id
