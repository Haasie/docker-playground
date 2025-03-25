@description('The Azure region for the resources')
param location string

@description('Name of the GUI VM')
param vmName string

@description('Admin username for the VM')
param adminUsername string

@description('SSH public key for the VM')
@secure()
param adminSshKey string

@description('ID of the subnet to connect the VM to')
param subnetId string

@description('Resource tags')
param tags object

// VM configuration
var vmSize = 'Standard_D2s_v3' // 2 vCPUs, 8 GB RAM
var osDiskType = 'Standard_LRS'
var imageReference = {
  publisher: 'Canonical'
  offer: '0001-com-ubuntu-server-jammy'
  sku: '22_04-lts'
  version: 'latest'
}

// Create network interface for VM
resource nic 'Microsoft.Network/networkInterfaces@2021-05-01' = {
  name: '${vmName}-nic'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

// Create VM
resource vm 'Microsoft.Compute/virtualMachines@2021-11-01' = {
  name: vmName
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: osDiskType
        }
      }
      imageReference: imageReference
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: adminSshKey
            }
          ]
        }
      }
    }
    priority: 'Spot' // Use Spot instance for cost savings
    evictionPolicy: 'Deallocate'
    billingProfile: {
      maxPrice: -1 // -1 means Azure won't evict based on price
    }
  }
}

// Auto-shutdown schedule (20:00 to 08:00)
resource autoShutdown 'Microsoft.DevTestLab/schedules@2018-09-15' = {
  name: 'shutdown-computevm-${vmName}'
  location: location
  tags: tags
  properties: {
    status: 'Enabled'
    taskType: 'ComputeVmShutdownTask'
    dailyRecurrence: {
      time: '20:00'
    }
    timeZoneId: 'W. Europe Standard Time'
    targetResourceId: vm.id
    notificationSettings: {
      status: 'Disabled'
    }
  }
}

// Outputs
output vmId string = vm.id
output vmPrivateIp string = nic.properties.ipConfigurations[0].properties.privateIPAddress
