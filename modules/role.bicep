param roleName string
param principalId string
param principalType string = 'ServicePrincipal'
param roleDefinitionId string

resource role 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: roleName
  properties: {
    principalId: principalId
    principalType: principalType
    roleDefinitionId: roleDefinitionId
  }
}
