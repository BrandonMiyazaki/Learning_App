using '../main.bicep'

param environmentName = 'prod'
param location = 'eastus'
// NOTE: jwtSecret must be provided at deployment time.
// Use --parameters or Azure Key Vault references. NEVER commit secrets.
// SQL authentication is disabled — the App Service managed identity is the Entra admin.
// Example:
//   az deployment group create \
//     --resource-group rg-learningapp-prod \
//     --template-file infra/main.bicep \
//     --parameters infra/parameters/prod.bicepparam \
//     --parameters jwtSecret='<secure-value>'
param jwtSecret = ''
param appServiceSkuName = 'B1'
param sqlSkuName = 'GP_S_Gen5_2'
param sqlSkuTier = 'GeneralPurpose'
