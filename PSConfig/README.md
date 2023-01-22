# Configuration

The configuration information is used to adjust defaults and provide values to the BICEP files and any manipulation of resources.  It is a key file that needs to be updated before anything is deployed.  All the deployment scripts rely on it.

It is split into three sections - DEV, PROD and GENERAL.

DEV and PROD are generally a mirror of one another with changes to resource names and ip addressing.  GENERAL contains common components that are environment agnostic.

There are three general variables that are used to defined many of the dev/prod/general configuration details.

- $owner
    - The name of the organisation that will own the deployment
- $product
    - The Product name.  Ideally this should be a short code of no more that 5 characters.  E.g. TST
- $ADBaseDesktopOU
    - The Org Unit path that will become the base AD org unit where the AVD will create its desktop host/vmss objects
- $rdpProperties
    - the RDP properties that the hostpool will use

**GENERAL**
- tenantID - The Tenant ID in which the subscriptions reside
- ADDomain - The domain name to use for the AD deployment e.g. test.com
- ADUsername - The Username used for the Domain Admin (I suggest not using Admin or Administrator)
- ADForestScript - the path to the script that is used to create the AD Forest
- repoSoftware - the name of the Blob Container that hosts software that will be deployed to the image with image builder.
- scriptContainer - the storage container where build scripts are stored for images generated with the image builder
- swContainer - A folder within the repository where Test software is stored that will be uploaded to the repoSoftware container
- imageBuilderRoleName - the role that the image builder uses during deployment
- imageBuilderScriptRoleName - the RBAC role assigned to the scriptcontainer container
- imageBuilderSWRepoRoleName - the RBAC role assigned to the repoSoftware container
- buildScriptsCommonFolder - the local repository folder where the Build Scripts are stored
- desktopImageName - the Name of the desktop.  No spaces.  e.g. TESTDesktop
- rdpProperties - as for the global variable


**DEV/PROD**
- tags - A hash of tags to deploy with all resources and RGs
- subscriptionID - The ID of the subscription to deploy to
- subscriptionName - the name of the subscription to deploy to
- location - the Azure location where all the resources will be deployed (e.g. UKSouth)
- boundaryVnetCIDR - the CIDR of the boundary vnet (suggest /24)
- boundaryVnetBastionCIDR - the CIDR of the Bastion subnet within the Boundary Vnet (suggest /26)
- idVnetCIDR - The CIDR of the Vnet used for Identity.  this includes the Active Directory deployment, whether AD VM or AADDS (suggest /24)
- idSnetADCIDR - The subnet in which the AD subnet is deployed within the ID Vnet (suggest /26)
- ADStaticIpAddress - The static IP address to assign to the AD server
- VMADAutoShutdownTime - A default time to shudown the AD server (for lab only).  Leave as an empty string to prevent shutdown
- imageBuilderUserName - The name of the User Managed Identity (UMI) used by the Image Builder.  This will be created and used by the Image Builder to access resources such as storage accounts
- imageBuilderRGName - The Resource Group name used to deploy the Image Builder resources
- repoRG - The RG in which the software repository that contains repoSoftware and scriptContainer contains is located
- repoStorageName - the name of the storage account in the repoRG
- desktops - This is a hash of desktops and desktop settings that will be built.  See next section for the desktop settings.

 **Desktops**

 The Desktops hash within each environment provides the key details for each of the desktops being deployed.

The hash is defined as:

"name of the desktop (no spaces)" = @{
    "setting name" = "setting"
}

The "setting name" / "setting" are defined as:

- prefix  - the prefix to be used of all virtual machines and vmss instances
- ou - the desktop + environment specific AD organisational unit where this desktop will create its objects
- image - the name of the Image Builder image that will be used for this desktop
- rdpProperties  - as for the global settings unless there is a requirement for specific desktop settings
- hostPoolName - The name of the hostpool that will be built to hose the desktop
- hostPoolRG - The name of the RG where the hostpool and supporting resources will be created for this desktop
- vnetName - The name of the vnet that this AVD will use
- vnetCIDR - The CIDR of the vnet that all hosts in this hostpool will reside wither VM or VMSS based
- snetName - The name of the subnet that AVD will use to actually deploy the hosts or VMSS set up its instances
- snetCIDR - The CIDR that sites within the Vnet for this AVD desktop (if using a shared Vnet for all your AVD deployments, make sure each AVD has its own subnet)
- nsgName - the name of the Network Security Group that will be built and linked to the subnet
- appGroupName - The name of the App Group that will be created and where you need to add users for access to the AVD
- workspaceName - The name of the Workspace where the AVD desktop will be created.

## Deployment

For a default deployment in a test environment, most of the settings can be left as default.  The only onces that MUST be changed are:

- $owner
- $product
- $ADBaseDesktopOU
- tenantID
- ADDomain
- subscriptionID
- subscriptionName