// ============================================================================
// Chore App — Main Bicep Template
// Orchestrates all Azure resource deployments for the Chore App.
//
// Usage:
//   az group create --name rg-choreapp-dev --location eastus
//   az deployment group create \
//     --resource-group rg-choreapp-dev \
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

@description('SQL Server administrator login name')
param sqlAdminLogin string

@description('SQL Server administrator password')
@secure()
@minLength(12)
param sqlAdminPassword string

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

var appName = 'app-choreapp-${environmentName}'
var planName = 'plan-choreapp-${environmentName}'
var sqlServerName = 'sql-choreapp-${environmentName}'
var sqlDatabaseName = 'sqldb-choreapp-${environmentName}'
var appInsightsName = 'appi-choreapp-${environmentName}'

// ──────────── Modules ────────────

// 1. Application Insights (deploy first so we can pass connection string to App Service)
module monitoring 'modules/monitoring.bicep' = {
  name: 'monitoring-${environmentName}'
  params: {
    appInsightsName: appInsightsName
    location: location
  }
}

// 2. Azure SQL Database
module sqlDatabase 'modules/sqlDatabase.bicep' = {
  name: 'sqlDatabase-${environmentName}'
  params: {
    serverName: sqlServerName
    databaseName: sqlDatabaseName
    location: location
    sqlAdminLogin: sqlAdminLogin
    sqlAdminPassword: sqlAdminPassword
    skuName: sqlSkuName
    skuTier: sqlSkuTier
  }
}

// 3. Azure App Service (depends on monitoring + SQL for connection strings)
module appService 'modules/appService.bicep' = {
  name: 'appService-${environmentName}'
  params: {
    appName: appName
    planName: planName
    location: location
    skuName: appServiceSkuName
    appInsightsConnectionString: monitoring.outputs.connectionString
    databaseUrl: 'sqlserver://${sqlDatabase.outputs.sqlServerFqdn}:1433;database=${sqlDatabaseName};user=${sqlAdminLogin};password=${sqlAdminPassword};encrypt=true;trustServerCertificate=false'
    jwtSecret: jwtSecret
  }
}

// ──────────── Outputs ────────────

@description('App Service URL')
output appUrl string = 'https://${appService.outputs.appServiceHostName}'

@description('Staging slot URL')
output stagingUrl string = 'https://${appService.outputs.stagingSlotHostName}'

@description('SQL Server FQDN')
output sqlServerFqdn string = sqlDatabase.outputs.sqlServerFqdn

@description('Application Insights connection string')
output appInsightsConnectionString string = monitoring.outputs.connectionString
