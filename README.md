# To Deploy an environment

It is assumed you have powershell with the Azure powershell modules and BICEP installed.

1. Update the "PSConfig/deployConfig.psm1" file with your subscription and vnet details and any name changes
1. Deploy the Base infrastrcture
    1. Includes log analytics, bastion and a boundary vnet
1. Deploy an AD server
    1. Script will build out an identity vnet, add the server and set up a basic domain
    1. Alternativly deploy AADDS and a simple management VM with the AD RSAT tools and use this - this is by far the easiest option and fully integrates into AAD and Azure Files (if you need them).
    1. If you need to connect to Azure Files using just your AD, have a look at [this](https://learn.microsoft.com/en-us/azure/storage/files/storage-files-identity-auth-active-directory-enable)
1. (optional) deploy image builder to give you a custom image
1. Deploy the Traditional AVD service
    1. Script will deploy a vnet, domain added VMs, the hostpool etc.

# Running the scripts

## Base Infrastructure

```powershell
cd 2_0_BaseInfrastructure

#Dry run with log into azure
.\deploy.ps1 -localenv dev

#Live run, no required log into azure (if already done)
.\deploy.ps1 -localenv dev -dryrun $false -dologin $false
```

Takes about 10-15 mins.

## AD server

```powershell
cd 2_1_ADServer

#Live run
.\deploy.ps1 -localenv dev -dryrun $false -dologin $false
```

You will be asked for a domain admin password.  The domain admin username is set in the deployConfig.psm1 config file.

Takes 20-30 mins

Note: If you hit any issues relating to keyvault, have a look at the keyvault/networking settings that allow the VM and microsoft services.

Once completed, you will need to log into the AD server (via bastion set up earlier) and open Users and Computers, then create a new org unit for the AVD deployment (I will automate this at some point).  Then you need to update the deployConfig.psm1 with the OU you have just created (in $ADBaseDesktopOU).  This is where the computer objects will be registered.  It should be of the LDAP form e.g. OU=Desktops,DC=mydomain,DC=com

Next you need to create any additional "sub" OU's you need.  Typically you will have one for your desktop by name and if you do dev and prod, then perhaps another sub one.  In the default config, you will find it here:

```bicep
desktops = @{
                avdstd = @{
                    prefix = "$($product)avdstdd".ToLower()
                    ou = "OU=DEV,OU=AVDStd,$($ADBaseDesktopOU)"
```

This translates to a AD users and computers "folder" structure of mydomain.com -> Desktops -> AVDStd -> DEV

(optional) Finally you may need to set up a version of AD connect (assuming you are not using AADDS) if you want your VM based AD identities available in AAD.  The easiest one to do is set up "AD Connect Cloud Sync" but you will need a custom domain name for that.  Full instructions are provided in the README.md.  AD Connect is used to connect your AD VM to AAD.

If you have gone down the AADDS route, you will need a local VM with the AD RSAT tools installed, then create the OU as above.  AD connect is not required for AADDS as it is fully integrated.

**Note:** if you dont use AD connect you will need to change the "RDP Properties" in the hostpool and set "Azure AD authentication" to "RDP won't use Azure AD authentication to sign in".

## Build a custom image (optional)

Image builder is mainly configured in two parts. The first part deploys the common components such as storage (for software) and the gallery.  The second part adds the image templates and definitions, then kicks off an image build.

If you want to configure the image itself you will need to modify the 2a_SingleEnv\BuildScripts\InstallSoftware.ps1 script.  This is fairly well commented and relies on the Components/BuildScriptsCommon/InstallSoftwareLibrary.psm1

```powershell
cd 2_2_ImageBuilder

#Live run - build the common components (recommend running this bit even if you use a standard image as the gallery is referenced later)
.\1_deployCommon.ps1 -localenv dev -dryrun $false -dologin $false

#Live run - build the image (installModules only needed if the AZ.ImageBuilder module is not installed)
#if it fails with an access error, give it a couple of minutes and re-run.  Sometime it can take a few minutes for assigned IDs to take effect.
.\2a_deploySingleEnv.ps1 -localenv dev -dryrun $false -dologin $false -installModules $true

```

The common components bit should only take a couple of minutes.  The image build could take up to an hour (and perhaps longer).

## Deploy traditional AVD

If you have deployed the ImageBuilder package and are using a custom image, then make sure that the Image enstry under desktops in the config is reflecting of the image name.  My default it should already match.

### If not using a custom image built using the image builder

If you are **not** using a custom image and just want to use a Microsoft stock image you will need to replace and comment out some things otherwise jump on down the the "To run the build below".

The following needs to be replace:

```bicep
imageReference: {
    id: ComputeGalleryImage.id
}
```

in the *2_hosts.bicep* with something like this:

```bicep
imageReference: {
    offer: 'office-365'
    publisher: 'MicrosoftWindowsDesktop'
    sku: 'win10-22h2-avd-m365-g2'
    version: 'latest'
}
```

Would would also need to comment out the two gallery existing resource pulls

```bicep
//Pull in the Compute Gallery
// resource ComputeGallery 'Microsoft.Compute/galleries@2022-03-03' existing = {
//   name: galleryName
//   scope: resourceGroup(gallerySubscriptionId,galleryRG)
// }

// //Pull in the Compute Gallery Image
// resource ComputeGalleryImage 'Microsoft.Compute/galleries/images@2022-03-03' existing = {
//   name: galleryImageName
//   parent: ComputeGallery
// }
```

### To run the build

Before running the script below - **Make sure your AD server is switched on**!

To deploy run the following powershell script:

```powershell
cd 2_3_TraditionalAVD

#Live run - will deploy 2 hosts to the hostpool and a scaling plan
.\1_DeployTraditionalAVD.ps1 -localenv dev -dryrun $false -dologin $false -hostCount 2

#Live run - will deploy 2 hosts to the hostpool without the scaling plan
.\1_DeployTraditionalAVD.ps1 -localenv dev -dryrun $false -dologin $false -deployScaler $false -hostCount 2

```

The build time should not be too long - depends on the number of machines you are deploying.  Once completed you should have a working AD joined host pool.  Take a look at the host pool, you should see your VM have been added.  If you check Users and Computers on the AD server you should also now see the computer objects have been added.

If you are using an AD VM and have not created a user to sync up to AAD, you need to do so now (if you are using AD Conenct).  You then need to add that sync'ed use to "Assignments" in the Applciation group that was created as part of the build.

If you are not using AD Connect, you need to assign an AAD user to the Applicaiton Group (so they have access to the resources), connect to the [WVD portal](https://client.wvd.microsoft.com/arm/webclient/index.html) with that user. Then when you connect to the desktop you need to provide the local VM based AD credential when prompted.

If you run into trouble with the build, check the hosts that you have just deployed and have a look at the "Extensions + applications".  Most problems are as a result of a failed extension.  they should all say "Provisioning succeeded".  The "DesiredStateConfiguration" is the one that joins the VM to the host pool.  One that does sometime fail is the NetworkWatcherAgent.  In this case just remove the failed extension and rerun the script.

Finally if you take a look under useful scripts, you will find some scripts to add and remove hosts, do some cleaning etc. so you can modify an existing deployment without redeploying everything.