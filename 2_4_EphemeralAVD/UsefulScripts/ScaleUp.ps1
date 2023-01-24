<#
    .SYNOPSIS
        Add <n> hosts to an existing host pool

    .DESCRIPTION
        this script will scale the VMSS behind the Ephemeral AVD HostPool.  The script will take the HP REsource group name and VMSS Name from
        the config file unless once is specificed.

        NOTE: Make sure that the AD server you are using (shown in the deployconfig) is switched on and operational otherwise this will fail
#>
param (
    [Parameter(Mandatory)]
    [String]$localenv,
    [int]$addHosts = 0,
    [Bool]$dryrun = $true,
    [Bool]$dologin = $true,
    [string]$vmssName = "",
    [string]$vmssRG = "",
    [string]$desktopName = "avdeph"
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


#Get the nme and RG of the VMSS
if ($vmssName -eq "") {
    $vmssName = $localConfig.$localenv.desktops.$desktopName.vmssName
}
if ($vmssRG -eq "") {
    $vmssRG = $localConfig.$localenv.desktops.$desktopName.hostPoolRG
}

# Scale the scale set
Write-Host "Getting the current instance count for $vmssName" -ForegroundColor Green
$vmss = Get-AzVmss -ResourceGroupName $vmssRG -VMScaleSetName $vmssName
$instanceCount = $vmss.Sku.Capacity

if ($addHosts -le 0) {
    Write-Host "No increment specified." -ForegroundColor Yellow
    Write-Host "Current VMSS has $instanceCount hosts" -ForegroundColor Green
    exit 0
}

$newInstanceCount = $instanceCount + $addHosts

Write-Host "Scaling $vmssName from $instanceCount to $newInstanceCount - this operation may take a while" -ForegroundColor Green
#Record the start time
$starttime = Get-Date
Write-Host "Start Time: $starttime" -ForegroundColor Green

$vmss.Sku.Capacity = $newInstanceCount
Update-AzVmss -ResourceGroupName $vmssRG -Name $vmssName -VirtualMachineScaleSet $vmss

$endtime = Get-Date
#Work out the time difference between start and end time and print it as hours and minutes
$timediff = $endtime - $starttime


Write-Host "Finished: $(Get-Date $endtime).  Scale up took $($timediff.hours)h $($timediff.minutes)m $($timediff.seconds)s" -ForegroundColor Green