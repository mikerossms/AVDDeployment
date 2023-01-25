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
    [int]$removeHostsCount = 0,
    [Bool]$dryrun = $true,
    [Bool]$dologin = $true,
    [string]$vmssName = "",
    [string]$vmssRG = "",
    [string]$hpName = "",
    [string]$hpRG = "",
    [string]$desktopName = "avdeph",
    [string]$logOffUsers = $false
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

#Get the name and RG of the hostpool
if ($hpName -eq "") {
    $hpName = $localConfig.$localenv.desktops.$desktopName.hostPoolName
}
if ($hpRG -eq "") {
    $hpRG = $localConfig.$localenv.desktops.$desktopName.hostPoolRG
}

# Get the Scale the scale set
Write-Host "Getting the details for $vmssName" -ForegroundColor Green
$vmss = Get-AzVmss -ResourceGroupName $vmssRG -VMScaleSetName $vmssName
$instanceCount = $vmss.Sku.Capacity

# Get the host pool hosts
# Order them by 1: those with no users, 2: those with all disconnected state, 3: those that are in drain mode, 4: all other hosts
# Remove all hosts in category 1, then set 2,3,4 (to number required to satisify ask), to drain mode
# If category 2, then remove the hosts
# If category 3 or 4, give the users <n> minutes to log off (polling until that time) on the required number of machines
# Remove the category 3 then 4 hosts to satisify requirement.
# Remove the associated VMSS instances


# Get the list of hosts in a hostpool
$hostList = Get-AzWvdSessionHost -ResourceGroupName $hpRG -HostPoolName $hpName

#Get the active user sessions - logged in and disconnected
#$userSessions = Get-AzWvdUserSession -HostPoolName $hpName -ResourceGroupName $hpRG

#get list of hosts in a hostpool
# Record the number of logged in users, disconnected users, and the drain state of the host
$hostData = @()
foreach($hostItem in $hostList) {
    #$hpsName = ($hostItem.Id).Split('/')[-1]
    $sessions = $hostItem.Session
    $AllowNewSession = $hostItem.AllowNewSession
    $hostData += [PSCustomObject]@{
        "HostId" = $hostItem.Id
        "LoggedInUsers" = $sessions
        "AllowNewSession" = $AllowNewSession
    }
}

# Order the list
$orderedHostList = $hostData | Sort-Object -Property @{Expression="LoggedInUsers"; Ascending=$false}, @{Expression="AllowNewSession"; Ascending=$true}