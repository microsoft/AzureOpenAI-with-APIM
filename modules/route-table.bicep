param routeTableName string
param location string
param azureOpenAiPublicIpAddress string

resource routeTable 'Microsoft.Network/routeTables@2023-04-01' = {
  name: routeTableName
  location: location
  properties: {
    disableBgpRoutePropagation: false
  }
}

resource routeTableRoute 'Microsoft.Network/routeTables/routes@2023-04-01' = {
  parent: routeTable
  name: 'route_to_internet_for_aoai'
  properties: {
    addressPrefix: '${azureOpenAiPublicIpAddress}/32'
    nextHopType: 'Internet'
    hasBgpOverride: false
  }
}
