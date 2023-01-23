#Deploy as for Traditional
#then deploy the Ephemeral Scaler
#then configure the ephemeral scaler

param (
    [Parameter(Mandatory)]
    [String]$localenv,
    [Bool]$dryrun = $true,
    [Bool]$dologin = $true,
    [Bool]$deployHostPool = $true,
    [Bool]$deployVMSS = $true,
    [string]$desktopName = "avdeph",
    [int]$hostPoolTokenLengthDays = 30
)

#Import the central powershell configuration module
Import-Module ../PSConfig/deployConfig.psm1 -Force

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

#Deploy the bicep using a subscription based deployment
if ($dryrun) {
    Write-Host "DRYRUN: Running the Infrastructure Build - Deploying Resources" -ForegroundColor Yellow
} else {
    Write-Host "LIVE: Running the Infrastructure Build - Deploying Resources" -ForegroundColor Green
}

#Deploy baseline infra and the hostpool
if ($deployHostPool) {
    Write-Host "Deploying the Host Pool and supporting infrastructure" -ForegroundColor Green
    $er = ""
    $out1 = New-AzSubscriptionDeployment -Name "EphemeralAVDHostPoolDeployment" -Location $localConfig.$localenv.location -Verbose -TemplateFile ".\Bicep\1_hostpool.bicep" -WhatIf:$dryrun -ErrorVariable er -TemplateParameterObject @{
        localenv=$localenv
        location=$localConfig.$localenv.location
        tags=$localConfig.$localenv.tags
        productShortName = $localConfig.general.productShortName
        adDomainName = $localConfig.general.ADDomain
        adServerIPAddresses = @($localConfig.$localenv.ADStaticIpAddress)
        galleryImageName = $localConfig.$localenv.desktops.$desktopName.image
        avdVnetName = $localConfig.$localenv.desktops.$desktopName.vnetName
        avdVnetCIDR = $localConfig.$localenv.desktops.$desktopName.vnetCIDR
        avdSubnetName = $localConfig.$localenv.desktops.$desktopName.snetName
        avdSubnetCIDR = $localConfig.$localenv.desktops.$desktopName.snetCIDR
        avdNSGName = $localConfig.$localenv.desktops.$desktopName.nsgName
        hostpoolName = $localConfig.$localenv.desktops.$desktopName.hostPoolName
        RGAVDName = $localConfig.$localenv.desktops.$desktopName.hostPoolRG
        hostPoolHostNamePrefix = $localConfig.$localenv.desktops.$desktopName.prefix
        hostPoolRDPProperties = $localConfig.$localenv.desktops.$desktopName.rdpProperties
        hostPoolAppGroupName = $localConfig.$localenv.desktops.$desktopName.appGroupName
        hostPoolWorkspaceName = $localConfig.$localenv.desktops.$desktopName.workspaceName
    }

    if ($er) {
        Write-Host "ERROR: Failed to deploy the hostpool" -ForegroundColor Red
        #Write-Host $er
        exit 1
    } else {
        Write-Host "Hostpool deployed successfully" -ForegroundColor Green
    }
}

#Deploy the VMSS to the HostPool
if ($deployVMSS) {
    #Generate a host pool token for this deployment
    Write-Host "Generate a new host pool token" -ForegroundColor Green
    $hpRG = $localConfig.$localenv.desktops.$desktopName.hostPoolRG
    $hpName = $localConfig.$localenv.desktops.$desktopName.hostPoolName
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

    #Check to see if the VMSS already exists
    $vmssName = $localConfig.$localenv.desktops.$desktopName.vmssName
    $vmss = Get-AzVmss -ResourceGroupName $hpRG -VMScaleSetName $vmssName -ErrorAction SilentlyContinue

    if ($vmss) {
        Write-Host "WARNING: The VMSS: $vmssName already exists in resource group: $hpRG.  Scaling to Zero before re-deployment due to new hostpool token" -ForegroundColor Red
        #Scale the VMSS to zero
        if ($dryrun) {
            Write-Host "DRYRUN: Scaling the VMSS to zero" -ForegroundColor Yellow
        } else {
            $vmss = Set-AzVmss -VirtualMachineScaleSet $vmss -Capacity 0
        }
    }


    Write-Host "Deploying the VMSS and joining it to the HostPool" -ForegroundColor Green
    $er = ""
    $out2 = New-AzSubscriptionDeployment -Name "StandardAVDHostsDeployment" -Location $localConfig.$localenv.location -Verbose -TemplateFile ".\Bicep\2_vmss.bicep" -WhatIf:$dryrun -ErrorVariable er -TemplateParameterObject @{
        localenv=$localenv
        location=$localConfig.$localenv.location
        tags=$localConfig.$localenv.tags
        productShortName = $localConfig.general.productShortName
        adDomainName = $localConfig.general.ADDomain
        adOUPath = $localConfig.$localenv.desktops.$desktopName.ou
        adDomainUsername = $localConfig.general.ADUsername
        avdVnetName = $localConfig.$localenv.desktops.$desktopName.vnetName
        avdSubnetName = $localConfig.$localenv.desktops.$desktopName.snetName
        hostpoolName = $hpName
        hostPoolRG = $hpRG
        galleryImageName = $localConfig.$localenv.desktops.$desktopName.image
        hostPoolToken = $hpToken
        vmssHostName = $localConfig.$localenv.desktops.$desktopName.vmssName
        vmssHostNamePrefix = ($localConfig.$localenv.desktops.$desktopName.prefix).SubString(0,9)
    }

    if ($er) {
        Write-Host "ERROR: Failed to deploy the hostpool" -ForegroundColor Red
        #Write-Host $er
        exit 1
    } else {
        Write-Host "Hostpool deployed successfully" -ForegroundColor Green
    }
}

Write-Host "Finished Deployment" -foregroundColor Green

Write-Host "VMSS solutions will likley need a scaling solution.  Azure does not provide one out of the box."
Write-Host "The next script '2_DeployEphemeralScaler.ps1' can be used to deploy the Automation Account customer VMSS scaling scripts"

Write-Host "In order to log into AVD, go here: https://client.wvd.microsoft.com/arm/webclient/index.html"
Write-Host "Remember that in order to log in you will need to add a user to the Application Group"
Write-Host ""