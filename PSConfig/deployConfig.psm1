function Get-Config {

    $owner = "Quberatron"
    $product = "QBX"
    $productShortName = ($product.ToUpper()).Substring(0,3)  #Max 3 characters
    $ADBaseDesktopOU = 'OU=Desktops,DC=quberatron,DC=com'
    $rdpProperties = "audiocapturemode:i:1;audiomode:i:0;drivestoredirect:s:;redirectclipboard:i:1;redirectcomports:i:0;redirectprinters:i:1;redirectsmartcards:i:1;screen mode id:i:2;autoreconnection enabled:i:1;bandwidthautodetect:i:1;networkautodetect:i:1;compression:i:1;videoplaybackmode:i:1;redirectlocation:i:0;redirectwebauthn:i:1;use multimon:i:1;dynamic resolution:i:1"

    $config = @{
        dev = @{
            tags = @{
                Environment="DEV"
                Owner=$owner
                Product=$product
                ProductShortNanme=$productShortName
            }
            subscriptionID = "8eef5bcc-4fc3-43bc-b817-048a708743c3"
            subscriptionName = "CORE DEV"
            location = "uksouth"
            boundaryVnetCIDR = "10.245.0.0/24"
            boundaryVnetBastionCIDR = '10.245.0.0/26'
            idVnetCIDR = '10.245.8.0/24'
            idSnetADCIDR = '10.245.8.0/27'
            ADStaticIpAddress = '10.245.8.20'
            VMADAutoShutdownTime = '1900'
            imageBuilderUserName = "$productShortName-imagebuilder-dev".ToLower()
            imageBuilderRGName = "$productShortName-RG-IMAGES-DEV".ToUpper()
            repoRG = "$productShortName-RG-IMAGES-DEV".ToUpper()
            repoStorageName = "$($productShortName)stbuilderrepodev".ToLower()
            desktops = @{
                avdstd = @{
                    prefix = "qbxavdstdd"
                    ou = "OU=DEV,OU=AVDStd,$($ADBaseDesktopOU)"
                    image = "QBXDesktop"
                    rdpProperties = $rdpProperties
                    hostPoolName = "$($productShortName)-hp-avdstd-dev".ToLower()
                    hostPoolRG = "$productShortName".ToUpper()
                    vnetName = "$productShortName-vnet-avdstd-dev".ToLower()
                    vnetCIDR = '10.245.16.0/24'
                    snetName = "$productShortName-snet-avdstd-dev".ToLower()
                    snetCIDR = '10.245.16.0/24'
                    nsgName = "$productShortName-nsg-avdstd-dev".ToLower()
                    appGroupName = "$productShortName-ag-avdstd-dev".ToLower()
                    workspaceName = "$productShortName-ws-avdstd-dev".ToLower()
                }
                avdeph = @{
                    prefix = "qbxavdephd"
                    ou = "OU=DEV,OU=AVDEph,$($ADBaseDesktopOU)"
                    image = "QBXDesktop"
                    rdpProperties = $rdpProperties
                    hostPoolName = "$($productShortName)-hp-avdeph-dev".ToLower()
                    hostPoolRG = "$productShortName-RG-AVD-EPH-DEV".ToUpper()
                    vnetName = "$productShortName-vnet-avdeph-dev".ToLower()
                    vnetCIDR = '10.245.17.0/24'
                    snetName = "$productShortName-snet-avdeph-dev".ToLower()
                    snetCIDR = '10.245.17.0/24'
                    nsgName = "$productShortName-nsg-avdeph-dev".ToLower()
                    appGroupName = "$productShortName-ag-avdeph-dev".ToLower()
                    workspaceName = "$productShortName-ws-avdeph-dev".ToLower()
                    vmssName = "$productShortName-vmss-avdeph-dev".ToLower()
                    vmssInstancePrefix = "$($productShortName)avdepd".ToLower()
                }
            }
        }

        prod = @{
            tags = @{
                Environment="PROD"
                Owner=$owner
                Product=$product
                ProductShortName=$productShortName
            }
            subscriptionID = "ea66f27b-e8f6-4082-8dad-006a4e82fcf2"
            subscriptionName = "CORE PROD"
            location = "uksouth"
            boundaryVnetCIDR = "10.246.0.0/24"
            boundaryVnetBastionCIDR = '10.246.0.0/26'
            idVnetCIDR = '10.246.8.0/24'
            idSnetADCIDR = '10.246.8.0/27'
            ADStaticIpAddress = '10.246.8.20'
            VMADAutoShutdownTime = '1900'
            imageBuilderUserName = "$productShortName-imagebuilder-prod".ToLower()
            imageBuilderRGName = "$productShortName-RG-IMAGES-PROD".ToUpper()
            repoRG = "$productShortName-RG-IMAGES-PROD".ToUpper()
            repoStorageName = "$($productShortName)stbuilderrepoprod".ToLower()
            desktops = @{
                avdstd = @{
                    prefix = "qbxavdstdp"
                    ou = "OU=PROD,OU=AVDStd,$($ADBaseDesktopOU)"
                    image = "QBXDesktop"
                    rdpProperties = $rdpProperties
                    hostPoolName = "$($productShortName)-hp-avdstd-prod".ToLower()
                    hostPoolRG = "$productShortName-RG-AVD-STD-PROD".ToUpper()
                    vnetName = "$productShortName-vnet-avdstd-prod".ToLower()
                    vnetCIDR = '10.246.16.0/24'
                    snetName = "$productShortName-snet-avdstd-prod".ToLower()
                    snetCIDR = "'10.246.16.0/24'"
                    nsgName = "$productShortName-nsg-avdstd-prod".ToLower()
                    appGroupName = "$productShortName-ag-avdstd-prod".ToLower()
                    workspaceName = "$productShortName-ws-avdstd-prod".ToLower()
                }
                avdeph = @{
                    prefix = "qbxavdephp"
                    ou = "OU=PROD,OU=AVDEph,$($ADBaseDesktopOU)"
                    image = "QBXDesktop"
                    rdpProperties = $rdpProperties
                    hostPoolName = "$($productShortName)-hp-avdeph-prod".ToLower()
                    hostPoolRG = "$productShortName-RG-AVD-EPH-PROD".ToUpper()
                    vnetName = "$productShortName-vnet-avdstd-prod".ToLower()
                    vnetCIDR = '10.246.17.0/24'
                    snetName = "$productShortName-snet-avdeph-prod".ToLower()
                    snetCIDR = "'10.246.17.0/24'"
                    nsgName = "$productShortName-nsg-avdeph-prod".ToLower()
                    appGroupName = "$productShortName-ag-avdeph-prod".ToLower()
                    workspaceName = "$productShortName-ws-avdeph-prod".ToLower()
                    vmssName = "$productShortName-vmss-avdeph-prod".ToLower()
                    vmssInstancePrefix = "$($productShortName)avdepp".ToLower()
                }
            }
        }

        general = @{
            tenantID = "b97e741f-846c-46ce-ba46-2d2dcf9abc38"
            ADDomain = 'quberatron.com'
            ADUsername = 'commander'
            ADForestScript = 'scripts/CreateForest.ps1'
            repoSoftware = 'repository'
            scriptContainer = 'buildscripts'
            swContainer = 'TestSoftware'
            imageBuilderRoleName = "Contributor"
            imageBuilderScriptRoleName = "Storage Blob Data Contributor"
            imageBuilderSWRepoRoleName = "Storage Blob Data Reader"
            buildScriptsCommonFolder = "Components/BuildScriptsCommon"
            desktopImageName = "QBXDesktop"
            owner = $owner
            product = $product
            productShortName = $productShortName
            rdpProperties = $rdpProperties
        }
    }

    return $config
}

Export-ModuleMember -Function Get-Config
