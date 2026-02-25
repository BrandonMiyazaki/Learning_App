// ============================================================================
// Azure SQL Server + Database
// Deploys a logical SQL Server and a single database with security hardening.
// ============================================================================

@description('Name of the Azure SQL logical server')
param serverName string

@description('Name of the Azure SQL database')
param databaseName string

@description('Azure region for all resources')
param location string

@description('SQL Server admin username')
param sqlAdminLogin string

@description('SQL Server admin password — must meet complexity requirements')
@secure()
@minLength(12)
param sqlAdminPassword string

@description('Database SKU name')
@allowed([
  'Basic'
  'S0'
  'GP_S_Gen5_1'   // General Purpose Serverless (1 vCore)
  'GP_S_Gen5_2'   // General Purpose Serverless (2 vCores)
])
param skuName string = 'GP_S_Gen5_1'

@description('Database SKU tier')
@allowed([
  'Basic'
  'Standard'
  'GeneralPurpose'
])
param skuTier string = 'GeneralPurpose'

@description('Enable auto-pause for serverless SKUs (minutes of inactivity, 0 = disabled)')
param autoPauseDelay int = 60

@description('Minimum vCores for serverless SKU')
param minCapacity string = '0.5'

// ---------- SQL Server ----------
resource sqlServer 'Microsoft.Sql/servers@2023-08-01-preview' = {
  name: serverName
  location: location
  properties: {
    administratorLogin: sqlAdminLogin
    administratorLoginPassword: sqlAdminPassword
    version: '12.0'
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled' // Restrict further in production
  }
}

// ---------- Firewall: Allow Azure Services ----------
resource firewallAllowAzure 'Microsoft.Sql/servers/firewallRules@2023-08-01-preview' = {
  parent: sqlServer
  name: 'AllowAllAzureIps'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// ---------- SQL Database ----------
resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-08-01-preview' = {
  parent: sqlServer
  name: databaseName
  location: location
  sku: {
    name: skuName
    tier: skuTier
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 2147483648 // 2 GB — sufficient for small app; scale as needed
    autoPauseDelay: (skuTier == 'GeneralPurpose') ? autoPauseDelay : 0
    minCapacity: (skuTier == 'GeneralPurpose') ? json(minCapacity) : null
    zoneRedundant: false
    requestedBackupStorageRedundancy: 'Local'
  }
}

// ---------- Auditing (Security Best Practice) ----------
resource sqlAuditing 'Microsoft.Sql/servers/auditingSettings@2023-08-01-preview' = {
  parent: sqlServer
  name: 'default'
  properties: {
    state: 'Enabled'
    isAzureMonitorTargetEnabled: true
    retentionDays: 90
  }
}

// ---------- Advanced Threat Protection ----------
resource threatProtection 'Microsoft.Sql/servers/securityAlertPolicies@2023-08-01-preview' = {
  parent: sqlServer
  name: 'default'
  properties: {
    state: 'Enabled'
    emailAccountAdmins: true
  }
}

// ---------- Outputs ----------
@description('Fully qualified domain name of the SQL Server')
output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName

@description('SQL Server resource ID')
output sqlServerId string = sqlServer.id

@description('SQL Database resource ID')
output sqlDatabaseId string = sqlDatabase.id

@description('Connection string template (password placeholder)')
output connectionStringTemplate string = 'sqlserver://${sqlServer.properties.fullyQualifiedDomainName}:1433;database=${databaseName};user=${sqlAdminLogin};password={your_password};encrypt=true;trustServerCertificate=false'
