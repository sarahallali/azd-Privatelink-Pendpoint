targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of naming resource convention')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

@secure()
@description('Password for the Windows VM')
param vmAdminPassword string //no value specified, so user will get prompted for it during deployment

// Tags that should be applied to all resources.
// 
// Note that 'azd-service-name' tags should be applied separately to service host resources.
// Example usage:
//   tags: union(tags, { 'azd-service-name': <service name in azure.yaml> })
var tags = {
  'azd-env-name': environmentName
}
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))

resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: tags
}
module privatelink 'architecture.bicep' ={
name: 'privatelink'
scope:rg 
params:{
  vmAdminPassword  : vmAdminPassword 
  vmAdminUsername: 'azureuser'
  location : location
  environmentName : environmentName
  tags: tags
  storageAccounts_storageaccountdemoplink_name: 'strgpl${resourceToken}'

  }
}
