param location string
param logAnalyticsName string

@minValue(30)
@maxValue(730)
param retentionInDays int = 90

resource logAnalyticcsWorkspace 'Microsoft.OperationalInsights/workspaces@2020-08-01' = {
  name: logAnalyticsName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: retentionInDays
  }
}

output id string = logAnalyticcsWorkspace.id
