@description('The location in which the resources should be deployed.')
param location string = resourceGroup().location

@description('The vnet name where redis will be connected.')
param vnetName string

@description('The ip address prefix REDIS will use.')
param redisSubnetAddressPrefix string = '10.0.2.0/24'

@description('The ASE name where to host the applications')
param aseName string

@description('DNS suffix where the app will be deployed')
param aseDnsSuffix string

@description('The name of the key vault name')
param keyVaultName string

@description('The cosmos DB name')
param cosmosDbName string

@description('The name for the sql server')
param sqlServerName string

@description('The name for the sql database')
param sqlDatabaseName string

@description('The name for the storage account')
param storageAccountName string

@description('The name for the log analytics workspace')
param logAnalyticsWorkspace string = '${uniqueString(resourceGroup().id)}la'


var cosmosKeySecretName = 'CosmosKey'
var amrConnectionStringKeyName = 'RedisConnectionString'
var serviceBusListenerConnectionStringSecretName = 'ServiceBusListenerConnectionString'
var serviceBusSenderConnectionStringSecretName = 'ServiceBusSenderConnectionString'
var votingApiName = 'votingapiapp-${uniqueString(resourceGroup().id)}'
var votingWebName = 'votingwebapp-${uniqueString(resourceGroup().id)}'
var testWebName = 'testwebapp-${uniqueString(resourceGroup().id)}'
var votingFunctionName = 'votingfuncapp-${uniqueString(resourceGroup().id)}'
var votingApiPlanName = '${votingApiName}-plan'
var votingWebPlanName = '${votingWebName}-plan'
var testWebPlanName = '${testWebName}-plan'
var votingFunctionPlanName = '${votingFunctionName}-plan'
var aseId = resourceId('Microsoft.Web/hostingEnvironments', aseName)


resource keyVault 'Microsoft.KeyVault/vaults@2024-11-01' existing = {
  name: keyVaultName
}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2025-02-01' = {
  name: logAnalyticsWorkspace
  location: location
}

resource votingFunctionAppInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: votingFunctionName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Flow_Type: 'Redfield'
    Request_Source: 'AppServiceEnablementCreate'
    WorkspaceResourceId: logAnalytics.id
  }
}

resource votingApi 'Microsoft.Insights/components@2020-02-02' = {
  name: votingApiName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Flow_Type: 'Redfield'
    HockeyAppId: ''
    WorkspaceResourceId: logAnalytics.id
  }
}

resource votingWeb 'Microsoft.Insights/components@2020-02-02' = {
  name: votingWebName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Flow_Type: 'Redfield'
    HockeyAppId: ''
    WorkspaceResourceId: logAnalytics.id
  }
}

resource testWeb 'Microsoft.Insights/components@2020-02-02' = {
  name: testWebName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Flow_Type: 'Redfield'
    HockeyAppId: ''
    WorkspaceResourceId: logAnalytics.id
  }
}

resource votingFunctionPlan 'Microsoft.Web/serverfarms@2024-11-01' = {
  name: votingFunctionPlanName
  location: location
  sku: {
    name: 'I1V2'
    tier: 'IsolatedV2'
  }
  //kind: 'functionapp'
  properties: {
    //name: votingFunctionPlanName_var
    perSiteScaling: false
    reserved: false
    targetWorkerCount: 0
    targetWorkerSizeId: 0
    //hostingEnvironment: aseName
    hostingEnvironmentProfile: {
      id: aseId
    }
  }
}

resource votingApiPlan 'Microsoft.Web/serverfarms@2024-11-01' = {
  name: votingApiPlanName
  location: location
  sku: {
    name: 'I1V2'
    tier: 'IsolatedV2'
  }
  kind: 'app'
  properties: {
    //name: votingApiPlanName_var
    perSiteScaling: false
    reserved: false
    targetWorkerCount: 0
    targetWorkerSizeId: 0
    //hostingEnvironment: aseName
    hostingEnvironmentProfile: {
      id: aseId
    }
  }
}

resource votingWebPlan 'Microsoft.Web/serverfarms@2024-11-01' = {
  name: votingWebPlanName
  location: location
  sku: {
    name: 'I1V2'
    tier: 'IsolatedV2'
  }
  kind: 'app'
  properties: {
    //name: votingWebPlanName_var
    perSiteScaling: false
    reserved: false
    targetWorkerCount: 0
    targetWorkerSizeId: 0
    //hostingEnvironment: aseName
    hostingEnvironmentProfile: {
      id: aseId
    }
  }
}

resource testWebPlan 'Microsoft.Web/serverfarms@2024-11-01' = {
  name: testWebPlanName
  location: location
  sku: {
    name: 'I1V2'
    tier: 'IsolatedV2'
  }
  kind: 'app'
  properties: {
    //name: testWebPlanName_var
    perSiteScaling: false
    reserved: false
    targetWorkerCount: 0
    targetWorkerSizeId: 0
    //hostingEnvironment: aseName
    hostingEnvironmentProfile: {
      id: aseId
    }
  }
}

resource votingStorage 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageAccountName
}

resource votingFunction 'Microsoft.Web/sites@2024-11-01' = {
  name: votingFunctionName
  location: location
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    enabled: true
    hostingEnvironmentProfile: {
      id: aseId
    }
    serverFarmId: votingFunctionPlan.id
    siteConfig: {
      alwaysOn: true
      netFrameworkVersion: 'v9.0'
      use32BitWorkerProcess: false
      appSettings: [
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet-isolated'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: votingFunctionAppInsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: 'InstrumentationKey=${votingFunctionAppInsights.properties.InstrumentationKey}'
        }
        {
          name: 'SERVICEBUS_CONNECTION_STRING'
          value: '@Microsoft.KeyVault(SecretUri=https://${keyVaultName}.vault.azure.net/secrets/${serviceBusListenerConnectionStringSecretName})'
        }
        {
          name: 'sqldb_connection'
          value: 'Server=${sqlServerName}.database.windows.net,1433;Database=${sqlDatabaseName};'
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=${votingStorage.listKeys().keys[0].value};EndpointSuffix=core.windows.net'
        }
      ]
    }
  }
}

resource votingApiApp 'Microsoft.Web/sites@2024-11-01' = {
  name: votingApiName
  location: location
  kind: 'app'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    enabled: true
    hostingEnvironmentProfile: {
      id: aseId
    }
    serverFarmId: votingApiPlan.id
    siteConfig: {
      netFrameworkVersion: 'v9.0'
      use32BitWorkerProcess: false
      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: votingApi.properties.InstrumentationKey
        }
        {
          name: 'ApplicationInsights:InstrumentationKey'
          value: votingApi.properties.InstrumentationKey
        }
        {
          name: 'ConnectionStrings:SqlDbConnection'
          value: 'Server=${sqlServerName}.database.windows.net,1433;Database=${sqlDatabaseName};'
        }
      ]
    }
  }
}

resource votingWebApp 'Microsoft.Web/sites@2024-11-01' = {
  name: votingWebName
  location: location
  kind: 'app'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    enabled: true
    hostingEnvironmentProfile: {
      id: aseId
    }
    serverFarmId: votingWebPlan.id
    siteConfig: {
      netFrameworkVersion: 'v9.0'
      use32BitWorkerProcess: false
      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: votingWeb.properties.InstrumentationKey
        }
        {
          name: 'ConnectionStrings:sbConnectionString'
          value: '@Microsoft.KeyVault(SecretUri=https://${keyVaultName}.vault.azure.net/secrets/${serviceBusSenderConnectionStringSecretName})'
        }
        {
          name: 'ConnectionStrings:VotingDataAPIBaseUri'
          value: 'https://${votingApiApp.properties.hostNames[0]}'
        }
        {
          name: 'ApplicationInsights:InstrumentationKey'
          value: votingWeb.properties.InstrumentationKey
        }
        {
          name: 'ConnectionStrings:RedisConnectionString'
          value: '@Microsoft.KeyVault(SecretUri=https://${keyVaultName}.vault.azure.net/secrets/${amrConnectionStringKeyName})'
        }
        {
          name: 'ConnectionStrings:queueName'
          value: 'votingqueue'
        }
        {
          name: 'ConnectionStrings:CosmosUri'
          value: 'https://${cosmosDbName}.documents.azure.com:443/'
        }
        {
          name: 'ConnectionStrings:CosmosKey'
          value: '@Microsoft.KeyVault(SecretUri=https://${keyVaultName}.vault.azure.net/secrets/${cosmosKeySecretName})'
        }
      ]
    }
  }
}

resource testWebApp 'Microsoft.Web/sites@2024-11-01' = {
  name: testWebName
  location: location
  kind: 'app'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    enabled: true
    hostingEnvironmentProfile: {
      id: aseId
    }
    serverFarmId: testWebPlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: testWeb.properties.InstrumentationKey
        }
        {
          name: 'ApplicationInsights:InstrumentationKey'
          value: testWeb.properties.InstrumentationKey
        }
      ]
    }
  }
}

resource keyVaultAccessPolicy 'Microsoft.KeyVault/vaults/accessPolicies@2024-11-01' = {
  parent: keyVault
  name: 'add'
  properties: {
    accessPolicies: [
      {
        objectId: votingFunction.identity.principalId
        permissions: {
          secrets: ['get', 'list']
          keys: ['get', 'list']
        }
        tenantId: subscription().tenantId
      }
      {
        objectId: votingWebApp.identity.principalId
        permissions: {
          secrets: ['get', 'list']
          keys: ['get', 'list']
        }
        tenantId: subscription().tenantId
      }
      {
        objectId: votingApiApp.identity.principalId
        permissions: {
          secrets: ['get', 'list']
          keys: ['get', 'list']
        }
        tenantId: subscription().tenantId
      }
      {
        objectId: testWebApp.identity.principalId
        permissions: {
          secrets: ['get', 'list']
          keys: ['get', 'list']
        }
        tenantId: subscription().tenantId
      }
    ]
  }
}

output votingWebName string = votingWebName
output testWebName string = testWebName
output votingAppUrl string = '${votingWebName}.${aseDnsSuffix}'
output testAppUrl string = '${testWebName}.${aseDnsSuffix}'
output votingApiName string = votingApiName
output votingFunctionName string = votingFunctionName
output votingWebAppIdentityPrincipalId string = votingWebApp.identity.principalId
output votingApiIdentityPrincipalId string = votingApiApp.identity.principalId
output votingCounterFunctionIdentityPrincipalId string = votingFunction.identity.principalId

