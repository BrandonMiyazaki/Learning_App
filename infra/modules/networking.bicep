// ============================================================================
// Virtual Network + Subnets + Private DNS Zones
// Provides network isolation for App Service and Azure SQL via private endpoints.
// ============================================================================

@description('Name of the Virtual Network')
param vnetName string

@description('Azure region for all resources')
param location string

@description('VNet address prefix')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('Subnet address prefix for App Service VNet Integration')
param appSubnetPrefix string = '10.0.1.0/24'

@description('Subnet address prefix for private endpoints')
param privateEndpointSubnetPrefix string = '10.0.2.0/24'

// ---------- Virtual Network ----------
resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: 'snet-app-integration'
        properties: {
          addressPrefix: appSubnetPrefix
          delegations: [
            {
              name: 'delegation-appservice'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
        }
      }
      {
        name: 'snet-private-endpoints'
        properties: {
          addressPrefix: privateEndpointSubnetPrefix
        }
      }
    ]
  }
}

// ---------- Private DNS Zone: Azure SQL ----------
resource privateDnsZoneSql 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink${environment().suffixes.sqlServerHostname}'
  location: 'global'
}

resource privateDnsZoneSqlLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: privateDnsZoneSql
  name: '${vnetName}-sql-link'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: vnet.id
    }
    registrationEnabled: false
  }
}

// ---------- Private DNS Zone: App Service ----------
resource privateDnsZoneApp 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.azurewebsites.net'
  location: 'global'
}

resource privateDnsZoneAppLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: privateDnsZoneApp
  name: '${vnetName}-app-link'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: vnet.id
    }
    registrationEnabled: false
  }
}

// ---------- Outputs ----------
@description('VNet resource ID')
output vnetId string = vnet.id

@description('App Service integration subnet resource ID (delegated to Microsoft.Web/serverFarms)')
output appIntegrationSubnetId string = vnet.properties.subnets[0].id

@description('Private endpoint subnet resource ID')
output privateEndpointSubnetId string = vnet.properties.subnets[1].id

@description('SQL Private DNS Zone resource ID')
output sqlPrivateDnsZoneId string = privateDnsZoneSql.id

@description('App Service Private DNS Zone resource ID')
output appPrivateDnsZoneId string = privateDnsZoneApp.id
