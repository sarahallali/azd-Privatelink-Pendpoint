targetScope = 'resourceGroup'

param tags object
param environmentName string

@description('Username for the Virtual Machine.')
param vmAdminUsername string

@description('Password for the Virtual Machine. The password must be at least 12 characters long and have lower case, upper characters, digit and a special character (Regex match)')
@secure()
param vmAdminPassword string

@description('The size of the VM')
param vmSize string = 'Standard_D2_v3'
param storageAccounts_storageaccountdemoplink_name string 

@description('Location for all resources.')
param location string = resourceGroup().location

var vnetName = 'webappproducerapp-vnet'
var vnetConsumerName = 'VMconsumer-vnet'
var vnetAddressPrefix = '10.0.0.0/16'
var frontendSubnetPrefix = '10.0.1.0/24'
var frontendSubnetName = 'frontendSubnet'
var backendSubnetPrefix = '10.0.2.0/24'
var backendSubnetName = 'backendSubnet'
var consumerSubnetPrefix = '10.0.0.0/24'
var consumerSubnetName = 'myPESubnet'
var loadbalancerName = 'LB_private_link'
var backendPoolName = 'myBackEndPool'
var loadBalancerFrontEndIpConfigurationName = 'myFrontEnd'
var healthProbeName = 'myHealthProbe'
var NSGVMConsumer_var = 'VMconsumer-nsg'
var NSGVMProducer_var = 'Webappproducerapp-nsg'
var vmName = take('webappproducerapp${uniqueString(resourceGroup().id)}', 15)
var networkInterfaceName = '${vmName}NetInt'
var vmConsumerName = take('VMConsumer${uniqueString(resourceGroup().id)}', 15)
var publicIpAddressConsumerName = '${vmConsumerName}PublicIP'
var networkInterfaceConsumerName = '${vmConsumerName}NetInt'
var osDiskType = 'StandardSSD_LRS'
var loadbalancerId = loadbalancer.id

resource NSGVMConsumer 'Microsoft.Network/networkSecurityGroups@2024-01-01' = {
  name: NSGVMConsumer_var
  location: location
  properties: {
    securityRules: []
  }
}

resource storageAccounts_storageaccountdemoplink_name_resource 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccounts_storageaccountdemoplink_name
  location: location
  sku: {
    name: 'Standard_LRS'
    tier: 'Standard'
  }
  kind: 'StorageV2'
  properties: {
    dnsEndpointType: 'Standard'
    defaultToOAuthAuthentication: false
    publicNetworkAccess: 'Enabled'
    allowCrossTenantReplication: false
    isLocalUserEnabled: false
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: true
    allowSharedKeyAccess: true
    largeFileSharesState: 'Enabled'
    networkAcls: {
      resourceAccessRules: [
        {
          tenantId: '6a05dcb7-5d4b-428e-962b-3eb15376c17c'
          resourceId: '/subscriptions/3fdc4ec9-62ee-4f87-b053-fc24443239ad/providers/Microsoft.Security/datascanners/StorageDataScanner'
        }
      ]
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
      defaultAction: 'Allow'
    }
    supportsHttpsTrafficOnly: true
    encryption: {
      requireInfrastructureEncryption: false
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
        blob: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    accessTier: 'Hot'
  }
}

resource NSGVMProducer 'Microsoft.Network/networkSecurityGroups@2024-01-01' = {
  name: NSGVMProducer_var
  location: location
  properties: {
    securityRules: []
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2021-05-01' = {
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
        name: frontendSubnetName
        properties: {
          addressPrefix: frontendSubnetPrefix
          privateLinkServiceNetworkPolicies: 'Disabled'
        }
      }
      {
        name: backendSubnetName
        properties: {
          addressPrefix: backendSubnetPrefix
          networkSecurityGroup: {
            id: NSGVMProducer.id
          }
        }
      }
    ]
  }
}

resource loadbalancer 'Microsoft.Network/loadBalancers@2021-05-01' = {
  name: loadbalancerName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: loadBalancerFrontEndIpConfigurationName
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, frontendSubnetName)
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: backendPoolName
      }
    ]
    inboundNatRules: [
      {
        name: 'RDP-VM0'
        properties: {
          frontendIPConfiguration: {
            id: resourceId(
              'Microsoft.Network/loadBalancers/frontendIpConfigurations',
              loadbalancerName,
              loadBalancerFrontEndIpConfigurationName
            )
          }
          protocol: 'Tcp'
          frontendPort: 3389
          backendPort: 3389
          enableFloatingIP: false
        }
      }
    ]
    loadBalancingRules: [
      {
        name: 'myHTTPRule'
        properties: {
          frontendIPConfiguration: {
            id: resourceId(
              'Microsoft.Network/loadBalancers/frontendIpConfigurations',
              loadbalancerName,
              loadBalancerFrontEndIpConfigurationName
            )
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', loadbalancerName, backendPoolName)
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', loadbalancerName, healthProbeName)
          }
          protocol: 'Tcp'
          frontendPort: 80
          backendPort: 80
          idleTimeoutInMinutes: 15
        }
      }
    ]
    probes: [
      {
        properties: {
          protocol: 'Tcp'
          port: 80
          intervalInSeconds: 15
          numberOfProbes: 2
        }
        name: healthProbeName
      }
    ]
  }
  dependsOn: [
    vnet
  ]
}

resource networkInterface 'Microsoft.Network/networkInterfaces@2021-05-01' = {
  name: networkInterfaceName
  location: location
  tags: {
    displayName: networkInterfaceName
  }
  properties: {
    ipConfigurations: [
      {
        name: 'ipConfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, backendSubnetName)
          }
          loadBalancerBackendAddressPools: [
            {
              id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', loadbalancerName, backendPoolName)
            }
          ]
          loadBalancerInboundNatRules: [
            {
              id: resourceId('Microsoft.Network/loadBalancers/inboundNatRules/', loadbalancerName, 'RDP-VM0')
            }
          ]
        }
      }
    ]
  }
  dependsOn: [
    loadbalancer
  ]
}

resource vm 'Microsoft.Compute/virtualMachines@2021-11-01' = {
  name: vmName
  location: location
  tags: {
    displayName: vmName
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: vmAdminUsername
      adminPassword: vmAdminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2019-Datacenter'
        version: 'latest'
      }
      osDisk: {
        name: '${vmName}OsDisk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: osDiskType
        }
        diskSizeGB: 128
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.id
        }
      ]
    }
  }
}

resource vmName_installcustomscript 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = {
  parent: vm
  name: 'installcustomscript'
  location: location
  tags: {
    displayName: 'install software for Windows VM'
  }
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.9'
    autoUpgradeMinorVersion: true
    protectedSettings: {
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted Install-WindowsFeature -Name Web-Server'
    }
  }
}

resource vnetConsumer 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: vnetConsumerName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: consumerSubnetName
        properties: {
          addressPrefix: consumerSubnetPrefix
          privateEndpointNetworkPolicies: 'Disabled'
          networkSecurityGroup: {
            id: NSGVMConsumer.id
          }
        }
      }
      {
        name: backendSubnetName
        properties: {
          addressPrefix: backendSubnetPrefix
        }
      }
    ]
  }
}

resource publicIpAddressConsumer 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: publicIpAddressConsumerName
  location: location
  tags: {
    displayName: publicIpAddressConsumerName
  }
  properties: {
    publicIPAllocationMethod: 'Dynamic'
    dnsSettings: {
      domainNameLabel: toLower(vmConsumerName)
    }
  }
}

resource networkInterfaceConsumer 'Microsoft.Network/networkInterfaces@2021-05-01' = {
  name: networkInterfaceConsumerName
  location: location
  tags: {
    displayName: networkInterfaceConsumerName
  }
  properties: {
    ipConfigurations: [
      {
        name: 'ipConfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIpAddressConsumer.id
          }
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetConsumerName, consumerSubnetName)
          }
        }
      }
    ]
  }
  dependsOn: [
    vnetConsumer
  ]
}

resource vmConsumer 'Microsoft.Compute/virtualMachines@2021-11-01' = {
  name: vmConsumerName
  location: location
  tags: {
    displayName: vmConsumerName
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmConsumerName
      adminUsername: vmAdminUsername
      adminPassword: vmAdminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2019-Datacenter'
        version: 'latest'
      }
      osDisk: {
        name: '${vmConsumerName}OsDisk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: osDiskType
        }
        diskSizeGB: 128
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterfaceConsumer.id
        }
      ]
    }
  }
}
