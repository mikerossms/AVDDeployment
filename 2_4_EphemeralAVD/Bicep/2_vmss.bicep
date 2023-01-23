//Deploys an Ephemeral AVD setup using a hostpool and VMSS

targetScope = 'subscription'

//Parameters
@allowed([
  'dev'
  'prod'
])
@description('The local environment identifier.  Default: dev')
param localenv string = 'dev'

@description('Location of the Resources. Default: UK South')
param location string = 'uksouth'

@maxLength(4)
@description('Product Short Name e.g. TST - no more than 4 characters')
param productShortName string

@description('Tags to be applied to all resources')
param tags object = {
  Environment: localenv
  Product: productShortName
}

//LAW Resource Group name
@description ('The name of the Log Analytics Workspace Resource Group')
param RGLAW string = toUpper('${productShortName}-RG-Logs-${localenv}')

//LAW workspace
@description('Log Analytics Workspace Name')
param LAWorkspaceName string = toLower('${productShortName}-LAW-${localenv}')


//Host Pool parameters
@description('The name of the host pool')
param hostPoolName string = toLower('${productShortName}-HP-${localenv}')

@description('The name of the Resource Group hosuing the HostPool')
param hostPoolRG string = toUpper('${productShortName}-RG-AVD-STD-${localenv}')

@description('The token to use to join the hosts to the hostpool')
param hostPoolToken string

//VMSS Parameters
@description('The name of the VMSS attached to the host pool')
param vmssHostName string = toLower('${productShortName}-vmss-avdeph-${localenv}')

@description('The size of the Gen 2 Ephemeral enabled to deploy when scaling the VMSS')
param vmssHostSize string = 'Standard_E2ads_v5'

@description('The prefix to use for the VMSS hostnames - Max 9 characters')
@maxLength(9)
param vmssHostNamePrefix string = toLower('${productShortName}avdeph')

//Active Directory Settings
@description('The name of the AD domain to join the hosts to')
param adDomainName string

@description('The name of the AD OU to join the hosts to')
param adOUPath string

@description('The subscription ID of the AD Keyvault')
param adKeyVaultSubscriptionId string = subscription().subscriptionId

@description('The RG that the AD Keyvault is in')
param adKeyVaultRG string = toUpper('${productShortName}-RG-IDENTITY-${localenv}')

@description('The name of the keyvault to store the AD credentials')
param adKeyVaultName string = toLower('${productShortName}-kv-ad-${localenv}')

@description('The username of the AD domain account used to join the hosts to the domain')
param adDomainUsername string

//Image Builder Compute Gallery settings
@description('The Resource Group name where the Compute Gallery is located that hosts the image builder image')
param galleryRG string = toUpper('${productShortName}-RG-IMAGES-${localenv}')

@description('The subscription where the Compute Gallery is located')
param gallerySubscriptionId string = subscription().subscriptionId

@description('The name of the Compute Gallery')
param galleryName string = toLower('${productShortName}_cgal_${localenv}')

@description('The name of the Compute Gallery Image to use')
param galleryImageName string = 'QBXDesktop'

//AVD Settings
@description('The name of the virtual network')
param avdVnetName string = toLower('${productShortName}-vnet-avdhost-${localenv}')

@description('The name of the AVD Host subnet to create')
param avdSubnetName string = toLower('${productShortName}-snet-avdhost-${localenv}')


//VARIABLES
//var avdSubnetID = resourceId('Microsoft.Network/VirtualNetworks/subnets', avdVnetName, avdSubnetName)
var dscConfigURL = 'https://wvdportalstorageblob.blob.${environment().suffixes.storage}/galleryartifacts/Configuration.zip'

//RESOURCES
//Get the RG
resource RGAVDSTD 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  name: hostPoolRG
}

//Retrieve the CORE Log Analytics workspace
resource LAWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: LAWorkspaceName
  scope: resourceGroup(RGLAW)
}

//Pull in the Compute Gallery
resource ComputeGallery 'Microsoft.Compute/galleries@2022-03-03' existing = {
  name: galleryName
  scope: resourceGroup(gallerySubscriptionId,galleryRG)
}

//Pull in the Compute Gallery Image
resource ComputeGalleryImage 'Microsoft.Compute/galleries/images@2022-03-03' existing = {
  name: galleryImageName
  parent: ComputeGallery
}

//Pull in the AD Keyvault to get the joiner credentials
resource ADKeyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: adKeyVaultName
  scope: resourceGroup(adKeyVaultSubscriptionId,adKeyVaultRG)
}

resource avdSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' existing = {
  name: '${avdVnetName}/${avdSubnetName}'
  scope: RGAVDSTD
}

module virtualMachineScaleSets '../../ResourceModules/modules/Microsoft.Compute/virtualMachineScaleSets/deploy.bicep' = {
  scope: RGAVDSTD
  name: vmssHostName
  params: {
    location: location
    tags: tags
    skuName: vmssHostSize
    adminUsername: ADKeyVault.getSecret('ADAdminUsername')
    adminPassword: ADKeyVault.getSecret('ADAdminPassword')
    systemAssignedIdentity: true
    name: vmssHostName
    imageReference: {
      id: ComputeGalleryImage.id
    }
    osDisk: {
      createOption: 'fromImage'
      diskSizeGB: '128'
      managedDisk: {
        storageAccountType: 'Premium_LRS'
      }
    }
    osType: 'Windows'
    
    // Non-required parameters
    monitoringWorkspaceId: LAWorkspace.id
    diagnosticWorkspaceId: LAWorkspace.id
    diagnosticLogsRetentionInDays: 7

    extensionMonitoringAgentConfig: {
      enabled: true
    }

    extensionNetworkWatcherAgentConfig: {
      enabled: false
    }

    extensionDependencyAgentConfig: {
      enabled: true
    }

    extensionAntiMalwareConfig: {
      enabled: true
      settings: {
        AntimalwareEnabled: true
        Exclusions: {
          Extensions: '.log;.ldf'
          Paths: 'D:\\IISlogs;D:\\DatabaseLogs'
          Processes: 'mssence.svc'
        }
        RealtimeProtectionEnabled: true
        ScheduledScanSettings: {
          day: '7'
          isEnabled: 'true'
          scanType: 'Quick'
          time: '120'
        }
      }
    }

    nicConfigurations: [
      {
        ipConfigurations: [
          {
            name: vmssHostNamePrefix
            properties: {
              subnet: {
                id: avdSubnet.id
              }
            }
          }
        ]
        nicSuffix: '-nic-01'
      }
    ]
    skuCapacity: 1
    upgradePolicyMode: 'Manual'
    vmNamePrefix: vmssHostNamePrefix
    vmPriority: 'Regular'
  }
}

//The following extensions should be installable as part of the VMSS module, but for some reason including them causes the deployment to fail
//with concurrency issues.  As a result, we need to install them in sequence rather than in parallel after VMSS has deployed

//Join the domain.  Due to a bug in the curated modules you cannot pass the password as a parameter, so we need to use a module
module virtualMachineScaleSetsExtDomainJoin './module_JoinDomain.bicep' = {
  name: 'virtualMachineScaleSetsExtDomainJoin'
  scope: RGAVDSTD
  params: {
    vmssName: virtualMachineScaleSets.name
    domainName: adDomainName
    domainAdminPassword: ADKeyVault.getSecret('ADAdminPassword')
    domainAdminUser: '${adDomainUsername}@${adDomainName}'
    domainJoinOUPath: adOUPath
  }
  dependsOn: [
    virtualMachineScaleSets
    //virtualMachineScaleSetsExtAntiMal
  ]
}

//Install DSC extension to connect VMSS to host pool - concurrent install issues if included as part of VMSS, so wait until VMSS is created and other extensions installed
module virtualMachineScaleSetsExtDSC '../../ResourceModules/modules/Microsoft.Compute/virtualMachineScaleSets/extensions/deploy.bicep' = {
  name: 'virtualMachineScaleSetsExtDSC'
  scope: RGAVDSTD
  params: {
    virtualMachineScaleSetName: virtualMachineScaleSets.name
    name: 'DesiredStateConfiguration'
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.77'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: false
    settings: {
      modulesUrl: dscConfigURL
      configurationFunction: 'Configuration.ps1\\AddSessionHost'
      properties: {
        HostPoolName: hostPoolName
        RegistrationInfoToken: hostPoolToken
      }
    }

  }
  dependsOn: [
    virtualMachineScaleSetsExtDomainJoin
  ]
} 

//Install Monitoring Agent on VMSS - concurrent install issues if included as part of VMSS, so wait until VMSS is created and other extensions installed
// module virtualMachineScaleSetsExtMonitoring '../../ResourceModules/modules/Microsoft.Compute/virtualMachineScaleSets/extensions/deploy.bicep' = {
//   name: 'virtualMachineScaleSetsExtMonitoring'
//   scope: RGAVDSTD
//   params: {
//     virtualMachineScaleSetName: virtualMachineScaleSets.name
//     name: 'MicrosoftMonitoringAgent'
//     publisher: 'Microsoft.EnterpriseCloud.Monitoring'
//     type: 'MicrosoftMonitoringAgent'
//     typeHandlerVersion: '1.7'
//     autoUpgradeMinorVersion: true
//     enableAutomaticUpgrade: false
//     settings: {
//       workspaceId: LAWorkspace.id 
//     }
//     protectedSettings: {
//       workspaceKey: LAWorkspace.listKeys().primarySharedKey
//     }

//   }
//   dependsOn: [
//     virtualMachineScaleSetsExtDSC
//   ]
// } 
