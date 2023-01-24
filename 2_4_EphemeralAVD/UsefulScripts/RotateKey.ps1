<#
    .SYNOPSIS
        Rotate the hostpool key and reintegrate that into the VMSS

    .DESCRIPTION
        this script will scale the VMSS to zero, rotate the hostpook key, reinitialise the DSC extension then scale the VMSS back up to the same capacity as it was before.
        NOTE: Make sure that the AD server you are using (shown in the deployconfig) is switched on and operational otherwise this will fail
#>
param (
    [Parameter(Mandatory)]
    [String]$localenv,
    [Bool]$dryrun = $true,
    [Bool]$dologin = $true,
    [string]$vmssName = "",
    [string]$vmssRG = "",
    [string]$hpName = "",
    [string]$hpRG = "",
    [string]$desktopName = "avdeph",
    [string]$logOffUsers = $false,
    [int]$hostPoolTokenLengthDays = 30
)

#Import the central powershell configuration module
Import-Module ../../PSConfig/deployConfig.psm1 -Force

#Import the Host Library
Import-Module "$PSScriptRoot/VMSSLibrary.psm1" -Force

#Get the local environment into a consistent state
$localenv = $localenv.ToLower()

if ((!$localenv) -and ($localenv -ne 'dev') -and ($localenv -ne 'prod')) {
    Write-Host "Error: Please specify a valid environment to deploy to [dev | prod]" -ForegroundColor Red
    exit 1
}

write-host "Working with environment: $localenv"

#Get the config for the selected local environment
$localConfig = Get-Config

#Login to azure
if ($dologin) {
    Write-Host "Log in to Azure using an account with permission to create Resource Groups and Assign Permissions" -ForegroundColor Green
    Connect-AzAccount -Subscription $localConfig.$localenv.subscriptionID
}

#Get the subsccription ID
$subid = (Get-AzContext).Subscription.Id

#check that the subscription ID matchs that in the config
if ($subid -ne $localConfig.$localenv.subscriptionID) {
    #they dont match so try and change the context
    Write-Host "Changing context to subscription: $subname ($subid)" -ForegroundColor Yellow
    $context = Set-AzContext -SubscriptionId $localConfig.$localenv.subscriptionID

    if ($context.Subscription.Id -ne $localConfig.$localenv.subscriptionID) {
        Write-Host "ERROR: Cannot change to subscription: $subname ($subid)" -ForegroundColor Red
        exit 1
    }

    Write-Host "Changed context to subscription: $subname ($subid)" -ForegroundColor Green
}

#Check if we are doing a DRYRUN (no change) of the deployment.
if ($dryrun) {
    Write-Host "DRYRUN: This will not deploy resources or make any changes" -ForegroundColor Yellow
} else {
    Write-Host "LIVE: This will deploy resources and make changes to infrastructure" -ForegroundColor Green
}


#Get the name and RG of the VMSS
if ($vmssName -eq "") {
    $vmssName = $localConfig.$localenv.desktops.$desktopName.vmssName
}
if ($vmssRG -eq "") {
    $vmssRG = $localConfig.$localenv.desktops.$desktopName.hostPoolRG
}

#Get the name and RG of the hostpool
if ($hpName -eq "") {
    $hpName = $localConfig.$localenv.desktops.$desktopName.hostPoolName
}
if ($hpRG -eq "") {
    $hpRG = $localConfig.$localenv.desktops.$desktopName.hostPoolRG
}

#Get the number of instances in the VMSS
$vmss = Get-AzVmss -ResourceGroupName $vmssRG -VMScaleSetName $vmssName
$instanceCount = $vmss.Sku.Capacity

#Check whether any users are logged in on the host pool
$hosts = Get-AzWvdSessionHost -ResourceGroupName $hpRG -HostPoolName $hpName -ErrorVariable er
$sessionCount = 0
foreach ($hostObject in $hosts) {
    if ($hostobject.Session) {
        $sessionCount++
    }
}

if ($sessionCount -gt 0) {
    if ($logOffUsers) {
        Write-Host "There are $sessionCount users logged in to the host pool. They will be logged off" -ForegroundColor Red
    } else {
        Write-Host "There are $sessionCount users logged in to the host pool. Please disconnect all users before continuing" -ForegroundColor Red
        exit 1
    }
}

#Remove all host pool hosts
Write-Host "Removing all host pool hosts" -ForegroundColor Yellow
foreach ($hostObject in $hosts) {
    #$hostObject    | convertto-json
    $hostName = ($hostObject.Name).split('/')[1]
    if (-not $dryrun) {
        Write-Host "Remove Hostpool host: $($hostName)" -ForegroundColor Yellow
        Remove-AzWvdSessionHost -ResourceGroupName $hpRG -HostPoolName $hpName -Name $($hostName)
    } else {
        Write-Host "DRYRUN: Remove Hostpool host: $($hostName)" -ForegroundColor Yellow
    }
}


#Scale the VMSS to zero
if (-not $dryrun) {
    Write-Host "Scaling the VMSS to zero" -ForegroundColor Yellow
    $vmss.Sku.capacity = 0
    Update-AzVmss -ResourceGroupName $vmssRG -Name $vmssName -VirtualMachineScaleSet $vmss
} else {
    Write-Host "DRYRUN: Scaling the VMSS to zero" -ForegroundColor Yellow
}

#Rotate the hostpool key
Write-Host "Generate a new host pool token" -ForegroundColor Green
$hpToken = ""
$midnightTimeThisMorning = Get-Date -Hour 0 -Minute 0 -Second 0
$expiryTime = $((Get-Date $midnightTimeThisMorning).ToUniversalTime().AddDays($hostPoolTokenLengthDays).ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ'))
if ($dryrun) {
    Write-Host "DRYRUN: Generating new host pool token for $hostPoolTokenLengthDays days" -ForegroundColor Yellow
} else {
    $hpToken = (New-AzWvdRegistrationInfo -HostPoolName $hpName -ResourceGroupName $hpRG -ExpirationTime $expiryTime).token

    if (-not $hpToken) {
        Write-Host "ERROR: Unable to generate a new host pool token" -ForegroundColor Red
        exit 1
    }
}

#Delete the VMSS DSC extension
if ($dryrun) {
    Write-Host "DRYRUN: Deleting the DSC extension" -ForegroundColor Yellow
} else {
    Write-Host "Deleting the DSC extension" -ForegroundColor Green
    Remove-AzVmssExtension -VirtualMachineScaleSet $vmss -Name "DesiredStateConfiguration"
    Update-AzVmss -ResourceGroupName $vmssRG -Name $vmssName -VirtualMachineScaleSet $vmss
}

#Re-add the DSC extension with the new HostPool token
if ($dryrun) {
    Write-Host "DRYRUN: Re-adding the DSC extension with the new host pool token" -ForegroundColor Yellow
} else {
    Write-Host "Re-adding the DSC extension with the new host pool token" -ForegroundColor Green
    $publicSettings =  @{
        modulesUrl = "https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration.zip"
        configurationFunction = "Configuration.ps1\\AddSessionHost"
        properties = @{
            HostPoolName = $hpName
            RegistrationInfoToken = $hpToken
        }
    }

    Add-AzVmssExtension -VirtualMachineScaleSet $vmss -Name "DesiredStateConfiguration" -Publisher "Microsoft.Powershell"  `
        -Type "DSC" -TypeHandlerVersion "2.77" -AutoUpgradeMinorVersion $True  `
        -Setting $publicSettings
   
    Update-AzVmss -ResourceGroupName $vmssRG -Name $vmssName -VirtualMachineScaleSet $vmss
}

#Update the DSC extension in the VMSS with the new key (needs to be deserialised and reserialised)
#$dscExtensionConfig = ($vmss.VirtualMachineProfile.ExtensionProfile.Extensions | Where-Object {$_.Name -eq "DesiredStateConfiguration"} |ConvertTo-Json |ConvertFrom-Json).Settings
#(Get-AzVmssExtension -ResourceGroupName $vmssRG -VMScaleSetName $vmssName -Name "DSC").PublicSettings

# Update the hostpool key
#$dscExtensionConfig[0].properties.RegistrationInfoToken = $hpToken

# Update the DSC extension
# if ($dryrun) {
#     Write-Host "DRYRUN: Updating the DSC extension with the new host pool token" -ForegroundColor Yellow
# } else {
#     Write-Host "Updating the DSC extension with the new host pool token" -ForegroundColor Green
#     #Update-AzVmss -ResourceGroupName $vmssRG -VMScaleSetName $vmssName -Name "DesiredStateConfiguration"
#     #-ResourceGroupName $vmssRG -VMScaleSetName $vmssName -Name "DSC" -PublicSettings $dscExtensionConfig.configuration -TypeHandlerVersion $dscExtensionConfig.typeHandlerVersion
# }

#Scale the VMSS back up
# if (-not $dryrun) {
#     Write-Host "Scaling the VMSS back up to $instanceCount - this might take some time" -ForegroundColor Yellow
#     Update-AzVmss -ResourceGroupName $vmssRG -VMScaleSetName $vmssName -Capacity $instanceCount
# }

