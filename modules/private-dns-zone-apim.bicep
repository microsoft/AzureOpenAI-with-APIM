param privateDnsZoneName string
param apimName string
param vnetName string

resource parentAPIM 'Microsoft.ApiManagement/service@2023-03-01-preview' existing = {
  name: apimName
}

resource parentVnet 'Microsoft.ApiManagement/service@2023-03-01-preview' existing = {
  name: vnetName
}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateDnsZoneName
  location: 'global'
  properties: {}
}

resource aRecordRoot 'Microsoft.Network/privateDnsZones/A@2020-06-01' = {
  parent: privateDnsZone
  name: parentAPIM.name
  properties: {
    ttl: 3600
    aRecords: [
      {
        ipv4Address: parentAPIM.properties.privateIPAddresses[0]
      }
    ]
  }
}

resource aRecordDeveloper 'Microsoft.Network/privateDnsZones/A@2020-06-01' = {
  parent: privateDnsZone
  name: '${parentAPIM.name}.developer'
  properties: {
    ttl: 3600
    aRecords: [
      {
        ipv4Address: parentAPIM.properties.privateIPAddresses[0]
      }
    ]
  }
}

resource aRecordManagement 'Microsoft.Network/privateDnsZones/A@2020-06-01' = {
  parent: privateDnsZone
  name: '${parentAPIM.name}.management'
  properties: {
    ttl: 3600
    aRecords: [
      {
        ipv4Address: parentAPIM.properties.privateIPAddresses[0]
      }
    ]
  }
}

resource aRecordPortal 'Microsoft.Network/privateDnsZones/A@2020-06-01' = {
  parent: privateDnsZone
  name: '${parentAPIM.name}.portal'
  properties: {
    ttl: 3600
    aRecords: [
      {
        ipv4Address: parentAPIM.properties.privateIPAddresses[0]
      }
    ]
  }
}

resource aRecordScm 'Microsoft.Network/privateDnsZones/A@2020-06-01' = {
  parent: privateDnsZone
  name: '${parentAPIM.name}.scm'
  properties: {
    ttl: 3600
    aRecords: [
      {
        ipv4Address: parentAPIM.properties.privateIPAddresses[0]
      }
    ]
  }
}

resource soa 'Microsoft.Network/privateDnsZones/SOA@2020-06-01' = {
  parent: privateDnsZone
  name: '@'
  properties: {
    ttl: 3600
    soaRecord:{
      host: 'azureprivatedns.net'
      email: 'azureprivatedns-host.microsoft.com'
      serialNumber: 1
      refreshTime: 3600
      retryTime: 300
      expireTime: 2419200
      minimumTtl: 10
    }
  }
}

resource virtualNetworkLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZone
  name: parentAPIM.name
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id:  resourceId('Microsoft.Network/VirtualNetworks', parentVnet.name)
    }
  }
  dependsOn: [
    parentVnet
  ]
}
