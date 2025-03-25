@description('The Azure region for the resources')
param location string = resourceGroup().location

@description('Environment name (e.g., dev, test, prod)')
param environmentName string = 'dev'

@description('Username for the GUI VM')
param adminUsername string

@description('SSH public key for the GUI VM')
@secure()
param adminSshKey string

@description('Azure AD Group Object ID for Admins')
param adminGroupObjectId string

// Tags for all resources
var tags = {
  Environment: environmentName
  Project: 'AzureDockerPlayground'
  DeployedBy: 'Bicep'
}

// Resource naming convention
var baseName = 'adp-${environmentName}'
var acrName = replace('${baseName}acr', '-', '')
var vnetName = '${baseName}-vnet'
var bastionName = '${baseName}-bastion'
var guiVmName = '${baseName}-gui-vm'

// Deploy network resources
module network './network.bicep' = {
  name: 'networkDeploy'
  params: {
    location: location
    vnetName: vnetName
    bastionName: bastionName
    tags: tags
  }
}

// Deploy Azure Container Registry (simplified)
module acr './acr.bicep' = {
  name: 'acrDeploy'
  params: {
    location: location
    acrName: acrName
    vnetId: network.outputs.vnetId // Still needed for parameter validation
    subnetId: network.outputs.privateSubnetId // Still needed for parameter validation
    adminGroupObjectId: adminGroupObjectId // Still needed for parameter validation
    tags: tags
  }
}

// Deploy GUI VM
module guiVm './gui-vm.bicep' = {
  name: 'guiVmDeploy'
  params: {
    location: location
    vmName: guiVmName
    adminUsername: adminUsername
    adminSshKey: adminSshKey
    subnetId: network.outputs.privateSubnetId
    tags: tags
  }
}

// Outputs
output vnetId string = network.outputs.vnetId
output bastionName string = bastionName
output guiVmName string = guiVmName
output guiVmPrivateIp string = guiVm.outputs.vmPrivateIp
output acrName string = acrName
