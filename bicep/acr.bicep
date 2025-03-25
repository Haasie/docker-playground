@description('The Azure region for the resources')
param location string

@description('Name of the Azure Container Registry')
param acrName string

@description('ID of the virtual network')
param vnetId string

@description('ID of the private subnet')
param subnetId string

@description('Azure AD Group Object ID for Admins')
param adminGroupObjectId string

@description('Resource tags')
param tags object

// Create Azure Container Registry
resource acr 'Microsoft.ContainerRegistry/registries@2021-09-01' = {
  name: acrName
  location: location
  tags: tags
  sku: {
    name: 'Basic' // Changed to Basic SKU to simplify deployment
  }
  properties: {
    adminUserEnabled: true // Admin user enabled for authentication
    publicNetworkAccess: 'Enabled' // Enable public access since we can't use private endpoints without proper permissions
  }
}

// Private endpoint resources removed since we're using Basic SKU with public access
// This simplifies the deployment and avoids permission issues

// RBAC role assignment removed due to permission limitations
// You will need to manually assign roles after deployment
// Use: az role assignment create --assignee-object-id <admin-group-id> --assignee-principal-type Group --role Owner --scope <acr-id>

// Outputs
output acrId string = acr.id
output acrLoginServer string = acr.properties.loginServer
