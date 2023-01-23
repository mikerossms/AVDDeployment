param vmssName string
param domainName string
param domainAdminUser string
@secure()
param domainAdminPassword string
param domainJoinOUPath string

//Join the domain.  Note that we are not using the module for this as the secure decordator on the protected settings is not working properly.
resource virtualMachineScaleSetsExtDomainJoin 'Microsoft.Compute/virtualMachineScaleSets/extensions@2022-03-01' = {
  name: '${vmssName}/virtualMachineScaleSetsExtDomainJoin'
  
  properties: {
      publisher: 'Microsoft.Compute'
      type: 'JsonADDomainExtension'
      typeHandlerVersion: '1.3'
      autoUpgradeMinorVersion: true
      enableAutomaticUpgrade: false
      settings: {
          name: domainName
          ouPath: domainJoinOUPath
          user: domainAdminUser
          restart: 'true'
          options: '3'
      }
      protectedSettings: {
        Password: domainAdminPassword
      }
  }
}
