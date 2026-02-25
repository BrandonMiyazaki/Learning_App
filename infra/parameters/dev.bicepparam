using '../main.bicep'

param environmentName = 'dev'
param location = 'eastus'
param sqlAdminLogin = 'choreappadmin'
// NOTE: sqlAdminPassword and jwtSecret must be provided at deployment time.
// Use --parameters or Azure Key Vault references. NEVER commit secrets.
// Example:
//   az deployment group create \
//     --resource-group rg-choreapp-dev \
//     --template-file infra/main.bicep \
//     --parameters infra/parameters/dev.bicepparam \
//     --parameters sqlAdminPassword='<secure-value>' jwtSecret='<secure-value>'
param appServiceSkuName = 'B1'
param sqlSkuName = 'GP_S_Gen5_1'
param sqlSkuTier = 'GeneralPurpose'
