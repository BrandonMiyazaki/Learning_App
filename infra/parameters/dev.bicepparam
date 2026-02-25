using '../main.bicep'

param environmentName = 'dev'
param location = 'westus2'
// NOTE: jwtSecret must be provided at deployment time.
// Use --parameters or Azure Key Vault references. NEVER commit secrets.
// SQL authentication is disabled — the App Service managed identity is the Entra admin.
// Example:
//   az deployment group create \
//     --resource-group rg-learningapp-dev \
//     --template-file infra/main.bicep \
//     --parameters infra/parameters/dev.bicepparam \
//     --parameters jwtSecret='<secure-value>'
param jwtSecret = ''
param appServiceSkuName = 'B1'
param sqlSkuName = 'GP_S_Gen5_1'
param sqlSkuTier = 'GeneralPurpose'
