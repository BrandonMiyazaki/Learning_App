// ============================================================================
// Azure App Service + App Service Plan
// Deploys a Linux Node.js App Service with a staging deployment slot.
// ============================================================================

@description('Name of the App Service')
param appName string

@description('Name of the App Service Plan')
param planName string

@description('Azure region for all resources')
param location string

@description('Node.js version for the runtime stack')
@allowed([
  '20-lts'
  '22-lts'
])
param nodeVersion string = '20-lts'

@description('App Service Plan SKU name')
@allowed([
  'B1'
  'B2'
  'S1'
  'P1v3'
])
param skuName string = 'B1'

@description('Application Insights connection string')
param appInsightsConnectionString string = ''

@description('Azure SQL connection string (uses managed identity, no password)')
param databaseUrl string = ''

@description('JWT secret for token signing')
@secure()
param jwtSecret string = ''

@description('Subnet resource ID for App Service VNet integration (delegated to Microsoft.Web/serverFarms)')
param appIntegrationSubnetId string

@description('Subnet resource ID for the App Service private endpoint')
param privateEndpointSubnetId string

@description('Private DNS Zone resource ID for privatelink.azurewebsites.net')
param appPrivateDnsZoneId string

// ---------- App Service Plan ----------
resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: planName
  location: location
  kind: 'linux'
  sku: {
    name: skuName
  }
  properties: {
    reserved: true // Required for Linux
  }
}

// ---------- App Service ----------
resource appService 'Microsoft.Web/sites@2023-12-01' = {
  name: appName
  location: location
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    virtualNetworkSubnetId: appIntegrationSubnetId
    publicNetworkAccess: 'Disabled'
    vnetRouteAllEnabled: true
    siteConfig: {
      linuxFxVersion: 'NODE|${nodeVersion}'
      alwaysOn: true
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      httpLoggingEnabled: true
      detailedErrorLoggingEnabled: true
      appSettings: [
        {
          name: 'NODE_ENV'
          value: 'production'
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~20'
        }
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'true'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsConnectionString
        }
        {
          name: 'JWT_SECRET'
          value: jwtSecret
        }
      ]
      connectionStrings: [
        {
          name: 'DATABASE_URL'
          connectionString: databaseUrl
          type: 'SQLAzure'
        }
      ]
      healthCheckPath: '/api/health'
    }
  }
}

// ---------- Private Endpoint: App Service ----------
resource appPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: 'pe-${appName}'
  location: location
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'plsc-${appName}'
        properties: {
          privateLinkServiceId: appService.id
          groupIds: [
            'sites'
          ]
        }
      }
    ]
  }
}

resource appPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01' = {
  parent: appPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-azurewebsites-net'
        properties: {
          privateDnsZoneId: appPrivateDnsZoneId
        }
      }
    ]
  }
}

// ---------- Outputs ----------
@description('App Service default hostname')
output appServiceHostName string = appService.properties.defaultHostName

@description('App Service resource ID')
output appServiceId string = appService.id

@description('App Service system-assigned managed identity principal ID')
output principalId string = appService.identity.principalId
