param eventHubNamespaceName string
param eventHubName string
param skuName string = 'Standard'
param skuCapacity int = 1
param location string = resourceGroup().location

resource eventHubNamespace 'Microsoft.EventHub/namespaces@2021-01-01-preview' = {
  name: eventHubNamespaceName
  location: location
  sku: {
    name: skuName
    capacity: skuCapacity
  }
}

resource eventHub 'Microsoft.EventHub/namespaces/eventhubs@2021-01-01-preview' = {
  parent: eventHubNamespace
  name: eventHubName
}

output namespaceId string = eventHubNamespace.id
output eventHubId string = eventHub.id
