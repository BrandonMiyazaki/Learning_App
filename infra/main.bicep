// ============================================================================
// Learning App — Main Bicep Template
// Orchestrates all Azure resource deployments for the Learning App.
//
// Usage:
//   az group create --name rg-learningapp-dev --location westus2
//   az deployment group create \
//     --resource-group rg-learningapp-dev \
//     --template-file infra/main.bicep \
//     --parameters infra/parameters/dev.bicepparam
// ============================================================================

targetScope = 'resourceGroup'

// ──────────── Parameters ────────────

@description('Environment name used in resource naming (dev, staging, prod)')
@allowed([
  'dev'
  'staging'
  'prod'
])
param environmentName string

@description('Azure region for all resources. Defaults to the resource group location.')
param location string = resourceGroup().location

@description('JWT secret for signing authentication tokens')
@secure()
param jwtSecret string

@description('App Service Plan SKU')
@allowed([
  'B1'
  'B2'
  'S1'
  'P1v3'
])
param appServiceSkuName string = 'B1'

@description('Azure SQL Database SKU name')
@allowed([
  'Basic'
  'S0'
  'GP_S_Gen5_1'
  'GP_S_Gen5_2'
])
param sqlSkuName string = 'GP_S_Gen5_1'

@description('Azure SQL Database SKU tier')
@allowed([
  'Basic'
  'Standard'
  'GeneralPurpose'
])
param sqlSkuTier string = 'GeneralPurpose'

// ──────────── Resource Names ────────────

var appName = 'app-learningapp-${environmentName}'
var planName = 'plan-learningapp-${environmentName}'
var sqlServerName = 'sql-learningapp-${environmentName}'
var sqlDatabaseName = 'sqldb-learningapp-${environmentName}'
var appInsightsName = 'appi-learningapp-${environmentName}'
var vnetName = 'vnet-learningapp-${environmentName}'

// ──────────── Modules ────────────

// 1. Application Insights (deploy first so we can pass connection string to App Service)
module monitoring 'modules/monitoring.bicep' = {
  name: 'monitoring-${environmentName}'
  params: {
    appInsightsName: appInsightsName
    location: location
  }
}

// 2. Virtual Network + Private DNS Zones (deploy before services that need them)
module networking 'modules/networking.bicep' = {
  name: 'networking-${environmentName}'
  params: {
    vnetName: vnetName
    location: location
  }
}

// 3. Azure App Service (deploy before SQL so we can use its managed identity)
module appService 'modules/appService.bicep' = {
  name: 'appService-${environmentName}'
  params: {
    appName: appName
    planName: planName
    location: location
    skuName: appServiceSkuName
    appInsightsConnectionString: monitoring.outputs.connectionString
    databaseUrl: 'sqlserver://${sqlServerName}.database.windows.net:1433;database=${sqlDatabaseName};encrypt=true;trustServerCertificate=false;authentication=ActiveDirectoryManagedIdentity'
    jwtSecret: jwtSecret
    appIntegrationSubnetId: networking.outputs.appIntegrationSubnetId
    privateEndpointSubnetId: networking.outputs.privateEndpointSubnetId
    appPrivateDnsZoneId: networking.outputs.appPrivateDnsZoneId
  }
}

// 4. Azure SQL Database (uses App Service managed identity as Entra admin)
module sqlDatabase 'modules/sqlDatabase.bicep' = {
  name: 'sqlDatabase-${environmentName}'
  params: {
    serverName: sqlServerName
    databaseName: sqlDatabaseName
    location: location
    entraAdminDisplayName: appName
    entraAdminPrincipalId: appService.outputs.principalId
    skuName: sqlSkuName
    skuTier: sqlSkuTier
    privateEndpointSubnetId: networking.outputs.privateEndpointSubnetId
    sqlPrivateDnsZoneId: networking.outputs.sqlPrivateDnsZoneId
  }
}

// ──────────── Outputs ────────────

@description('App Service URL')
output appUrl string = 'https://${appService.outputs.appServiceHostName}'

@description('SQL Server FQDN')
output sqlServerFqdn string = sqlDatabase.outputs.sqlServerFqdn

@description('Application Insights connection string')
output appInsightsConnectionString string = monitoring.outputs.connectionString

@description('Virtual Network resource ID')
output vnetId string = networking.outputs.vnetId
