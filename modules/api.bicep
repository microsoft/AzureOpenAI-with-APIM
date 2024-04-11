param apimName string
param apiName string
param apiPath string
param aiLoggerId string
param openApiJson string
param openApiXml string
param serviceUrlPrimary string
param serviceUrlSecondary string
param apiSubscriptionName string
param azureOpenAiRegionType string = 'Single'

resource parentAPIM 'Microsoft.ApiManagement/service@2023-03-01-preview' existing = {
  name: apimName
}

resource primarybackend 'Microsoft.ApiManagement/service/backends@2023-03-01-preview' = {
  name: 'aoai-primary-backend'
  parent: parentAPIM
  properties: {
    description: 'Primary AOAI endpoint'
    protocol: 'http'
    url: serviceUrlPrimary
  }
}

resource secondarybackend 'Microsoft.ApiManagement/service/backends@2023-03-01-preview' = if (azureOpenAiRegionType == 'Multi'){
  name: 'aoai-secondary-backend'
  parent: parentAPIM
  properties: {
    description: 'Secondary AOAI endpoint'
    protocol: 'http'
    url: serviceUrlSecondary
  }
}

resource api 'Microsoft.ApiManagement/service/apis@2023-03-01-preview' = {
  parent: parentAPIM
  name: apiName
  properties: {
    format: 'openapi+json-link'
    value: openApiJson
    path: apiPath
  }
}

resource apiPolicy 'Microsoft.ApiManagement/service/apis/policies@2023-03-01-preview' = {
  parent: api
  name: 'policy'
  properties: {
    format: 'xml-link'
    value: openApiXml
  }
}

resource adminUser 'Microsoft.ApiManagement/service/users/subscriptions@2023-05-01-preview' existing = {
  name: '/users/1'
}

resource apiSubscription 'Microsoft.ApiManagement/service/subscriptions@2023-03-01-preview' = {
  name: apiSubscriptionName
  parent: parentAPIM
  properties: {
    allowTracing: false
    displayName: apiSubscriptionName
    ownerId: adminUser.id
    scope: api.id
    state: 'active'
  }
}

resource diagnostic 'Microsoft.ApiManagement/service/diagnostics@2023-03-01-preview' = {
  parent: parentAPIM
  dependsOn: [api]
  name: 'applicationinsights'
  properties: {
    alwaysLog: 'allErrors'
    httpCorrelationProtocol: 'Legacy'
    verbosity: 'information'
    logClientIp: true
    loggerId: aiLoggerId
    sampling: {
      samplingType: 'fixed'
      percentage: 100
    }
    frontend: {
      request: {
        headers: []
        body: {
          bytes: 0
        }
      }
      response: {
        headers: []
        body: {
          bytes: 0
        }
      }
    }
    backend: {
      request: {
        headers: []
        body: {
          bytes: 0
        }
      }
      response: {
        headers: []
        body: {
          bytes: 0
        }
      }
    }
  }
}
