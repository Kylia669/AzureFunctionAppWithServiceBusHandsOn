@description('resource location')
param location string = 'westus'

@description('Name of the storage account')
param storageAccountName string = 'akylappstorage'

@description('Name of the function app')
param functionAppName string = 'akylfuncapp'

@description('Name of service bus namespace')
param serviceBusNamespaceName string = 'akylfuncappservicebus'


var managedIdentityName = '${functionAppName}-identity'
var appInsightsName = '${functionAppName}-appinsights'
var appServicePlanName = '${functionAppName}-appserviceplan'

var inputQueueName = '${serviceBusNamespaceName}-input'
var blobServiceUri = 'https://${storageAccountName}.blob.core.windows.net/'
var serviceBusNamespaceValue= '${serviceBusNamespaceName}.servicebus.windows.net'

var storageOwnerRoleDefinitionResourceId = '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
var serviceBusOwnerRoleDefinitionResourceId = '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/090c5cfd-751d-490a-894a-3ce6f1109419'


resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageAccountName
  location: location
  sku: {
	name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties:{
	  allowBlobPublicAccess: false
  }
}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: managedIdentityName
  location: location
}

resource storageOwnerPermission 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(storageAccount.id, functionAppName, storageOwnerRoleDefinitionResourceId)
  scope: storageAccount
  properties: {
	principalId: managedIdentity.properties.principalId
	roleDefinitionId: storageOwnerRoleDefinitionResourceId
  }
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
	Application_Type: 'web'
  }
}

resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: appServicePlanName
  location: location
  sku: {
	name: 'Y1'
	tier: 'Dynamic'
  }
}

resource functionApp 'Microsoft.Web/sites@2022-03-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {'${managedIdentity.id}': {}}
  }
  properties: {
	serverFarmId: appServicePlan.id
	siteConfig: {
	  appSettings: [
		{
		  name: 'AzureWebJobsStorage__credential'
		  value: 'managedidentity'
		}
		{
		  name: 'AzureWebJobsStorage__clientId'
		  value: managedIdentity.properties.clientId
		}
		{
		  name: 'AzureWebJobsStorage__accountName'
		  value: storageAccountName
		}
		{
		  name: 'AzureWebJobsStorage__blobServiceUri'
		  value: blobServiceUri
		}
		{
		  name: 'AzureWebJobsStorage'
		  value: 'fake'
		}
		{
		  name: 'FUNCTIONS_EXTENSION_VERSION'
		  value: '~4'
		}
		{
		  name: 'FUNCTIONS_WORKER_RUNTIME'
		  value: 'dotnet'
		}
		{
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: applicationInsights.properties.InstrumentationKey
        }
		{
          name: 'sbConnection__fullyQualifiedNamespace'
          value: serviceBusNamespaceValue
        }
		{
		  name: 'sbConnection__credential'
		  value: 'managedidentity'
		}
		{
		  name: 'sbConnection__clientId'
		  value: managedIdentity.properties.clientId
		}
	  ]
	}
  }
}

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2022-01-01-preview' = {
  name: serviceBusNamespaceName
  location: location
  sku: {
	name: 'Standard'
	tier: 'Standard'
  }
}

resource serviceBusOwnerPermission 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(serviceBusNamespace.id, functionAppName, serviceBusOwnerRoleDefinitionResourceId)
  scope: serviceBusNamespace
  properties: {
	principalId: managedIdentity.properties.principalId
	roleDefinitionId: serviceBusOwnerRoleDefinitionResourceId
  }
}

resource serviceBusNamespaceInputQueue 'Microsoft.ServiceBus/namespaces/queues@2022-01-01-preview' = {
  name: inputQueueName
  parent: serviceBusNamespace
  properties: {
	enablePartitioning: false
	enableExpress: false
	enableBatchedOperations: true,
	maxDeliveryCount: 1
  }
}
