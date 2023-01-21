<#
    .SYNOPSIS
    Sets the state of the scaling plan for a hostpool

    .DESCRIPTION
    Changes the state of the Azure Scaling Plan that is associated with the hostpool
    Effectivly enables or disables it.

#>

param (
    [Parameter(Mandatory)]
    [String]$localenv,
    [String]$desktopName = 'avdstd',
    [Parameter(Mandatory)]
    [Bool]$enabled,
    [Bool]$dologin = $true
)

#Import the central powershell configuration module
Import-Module ../../PSConfig/deployConfig.psm1 -Force

#Import the Host Library
Import-Module "$PSScriptRoot/hostLibrary.psm1" -Force

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

#Get the hostpool RG and name from the config
$hpRG = $localConfig.$localenv.desktops.$desktopName.hostPoolRG
$hpName = $localConfig.$localenv.desktops.$desktopName.hostPoolName

# Get the host pool details
$hostPool = Get-AzWvdHostPool -ResourceGroupName $hpRG -Name $hpName

# Check if the host pool exists
if (!$hostPool) {
    Write-Host "Error: Host pool does not exist, please check the name and resource group and try again" -ForegroundColor Red
    exit 1
}

# Get the scaling plan name associated with the host pool
$scalingPlanName = $hostPool.AutoscaleConfiguration.Name

# Check if the host pool has an associated scaling plan
if (!$scalingPlanName) {
    Write-Host "Host pool does not have an associated scaling plan - no actions" -ForegroundColor Red
    exit 0
}

# Get the current scaling plan
$scalingPlan = Get-AzVmssAutoscale -ResourceGroupName $resourceGroup -Name $scalingPlanName

# Update the scaling plan to the desired state
$scalingPlan.Enabled = $enable
Set-AzVmssAutoscale -AutoscaleSetting $scalingPlan

# Get the updated scaling plan
$updatedScalingPlan = Get-AzVmssAutoscale -ResourceGroupName $resourceGroup -Name $scalingPlanName

# Check if the state has changed correctly
if($enable -eq $updatedScalingPlan.Enabled){
    Write-Host "Scaling plan has been enabled successfully" -ForegroundColor Green
} else {
    Write-Host "Error: Scaling plan state change was not successful, please check the configuration and try again" -ForegroundColor Red
    exit 1
}

Write-Host "Deployment Complete" -ForegroundColor Green
exit 0

# #Check if there is a scale plan
# $scalePlanExists = Get-HostPoolScalingPlanExists -hostPoolName $hpName -hostPoolRG $hpRG
# if ($scalePlanExists) {
#     $scalePlanState = Get-HostPoolScalingPlanState -hostPoolName $hpName -hostPoolRG $hpRG

#     if ($scalePlanState -eq $enabled) {
#         Write-Host "Scaling plan is already in the desired state" -ForegroundColor Green
#         exit 0
#     }

#     Write-Host "Setting Scaling Plan for hostpool: $hpName to $state" -ForegroundColor Green
#     $result = Set-HostPoolScalingPlanState -hostPoolName $hpName -hostPoolRG $hpRG -enabled $enabled
#     if ($result) {
#         Write-Host "Scaling plan state change successful" -ForegroundColor Green
#     } else {
#         Write-Host "ERROR: Failed to change the state of the scaling plan" -ForegroundColor Red
#         exit 1
#     }

# } else {
#     Write-Host "No scale plan found for hostpool: $hpName" -ForegroundColor Yellow
#     exit 1
# }

# Write-Host "Deployment Complete" -ForegroundColor Green
