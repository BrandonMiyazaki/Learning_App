// ============================================================================
// Application Insights + Log Analytics Workspace
// Provides monitoring, diagnostics, and alerting for the App Service.
// ============================================================================

@description('Name of the Application Insights resource')
param appInsightsName string

@description('Azure region for all resources')
param location string

@description('Name of the Log Analytics workspace')
param logAnalyticsName string = '${appInsightsName}-law'

@description('Log Analytics retention in days')
@minValue(30)
@maxValue(730)
param retentionDays int = 30

// ---------- Log Analytics Workspace ----------
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: retentionDays
  }
}

// ---------- Application Insights ----------
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// ---------- Outputs ----------
@description('Application Insights connection string')
output connectionString string = appInsights.properties.ConnectionString

@description('Application Insights instrumentation key')
output instrumentationKey string = appInsights.properties.InstrumentationKey

@description('Application Insights resource ID')
output appInsightsId string = appInsights.id

@description('Log Analytics workspace ID')
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id
