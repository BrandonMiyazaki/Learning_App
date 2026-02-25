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

@description('Display name for the Entra ID admin (e.g. the App Service name)')
param entraAdminDisplayName string

@description('Object (principal) ID of the Entra ID admin (e.g. App Service managed identity)')
param entraAdminPrincipalId string

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

@description('Subnet resource ID for the SQL private endpoint')
param privateEndpointSubnetId string

@description('Private DNS Zone resource ID for privatelink.database.windows.net')
param sqlPrivateDnsZoneId string

// ---------- SQL Server ----------
resource sqlServer 'Microsoft.Sql/servers@2023-08-01-preview' = {
  name: serverName
  location: location
  properties: {
    version: '12.0'
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Disabled'
    administrators: {
      administratorType: 'ActiveDirectory'
      principalType: 'Application'
      login: entraAdminDisplayName
      sid: entraAdminPrincipalId
      tenantId: subscription().tenantId
      azureADOnlyAuthentication: true
    }
  }
}

// ---------- Private Endpoint: SQL Server ----------
resource sqlPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: 'pe-${serverName}'
  location: location
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'plsc-${serverName}'
        properties: {
          privateLinkServiceId: sqlServer.id
          groupIds: [
            'sqlServer'
          ]
        }
      }
    ]
  }
}

resource sqlPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01' = {
  parent: sqlPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-database-windows-net'
        properties: {
          privateDnsZoneId: sqlPrivateDnsZoneId
        }
      }
    ]
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

@description('Connection string template (managed identity)')
output connectionStringTemplate string = 'sqlserver://${sqlServer.properties.fullyQualifiedDomainName}:1433;database=${databaseName};encrypt=true;trustServerCertificate=false;authentication=ActiveDirectoryManagedIdentity'
