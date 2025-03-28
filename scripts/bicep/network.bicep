@description('The Azure region for the resources')
param location string

@description('Name of the virtual network')
param vnetName string

@description('Name of the bastion host')
param bastionName string

@description('Resource tags')
param tags object

// Network configuration
var vnetAddressPrefix = '10.0.0.0/16'
var privateSubnetName = 'private-subnet'
var privateSubnetPrefix = '10.0.1.0/24'
var bastionSubnetName = 'AzureBastionSubnet' // Must be named exactly this
var bastionSubnetPrefix = '10.0.0.0/27' // Must be at least /27

// Create Virtual Network with two subnets
resource vnet 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: privateSubnetName
        properties: {
          addressPrefix: privateSubnetPrefix
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: bastionSubnetName
        properties: {
          addressPrefix: bastionSubnetPrefix
        }
      }
    ]
  }
}

// Create public IP for Bastion (only public IP in the solution)
resource bastionPublicIp 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: '${bastionName}-pip'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// Create Azure Bastion Host
resource bastion 'Microsoft.Network/bastionHosts@2021-05-01' = {
  name: bastionName
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'IpConf'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, bastionSubnetName)
          }
          publicIPAddress: {
            id: bastionPublicIp.id
          }
        }
      }
    ]
  }
}

// Outputs
output vnetId string = vnet.id
output privateSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, privateSubnetName)
output bastionSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, bastionSubnetName)
