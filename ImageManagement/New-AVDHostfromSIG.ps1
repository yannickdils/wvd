#region variables

# General Variables

$ResourceGroup = Get-AzResourceGroup | Out-GridView -Title "Please select the resource group where you want to deploy your AVD host" -PassThru # Resource Group Selection

# Image Variables

$imagegallery = Get-AzGallery | Out-GridView -Title "Select the SIG you want to use" -PassThru # Gallery Selection
$imagegallerydefinitioninfo = Get-AzGalleryImageDefinition -GalleryName $imagegallery.Name -ResourceGroupName $imagegallery.ResourceGroupName | Out-GridView -Title "Select the SIG Definition" -PassThru # Image Definition Selection
$imagegalleryinfo = Get-AzGalleryImageVersion -GalleryName $imagegallery.Name -ResourceGroupName $imagegallery.ResourceGroupName -GalleryImageDefinitionName $imagegallerydefinitioninfo.Name | Out-GridView -Title "Select the SIG Image Version" -PassThru # Image Version Selection
$imagereference = @{"id" = $imagegalleryinfo.Id }

$vmprefix = read-host "Enter a virtual machine prefix" # Enter the virtual machine prefix (something like wvd, avd, avdmulti, avdsingle)
$vmsize = "Standard_D4s_v3" # Enter a virtual machine size
$vmcount = "1" # Enter the amount of virtual machine you like
$vmoffset = "0" # Enter the start number of your virtual machine
$vmstorage = "Premium_LRS" # Enter the storage type
$vmlicensetype = "Windows_Server" # Enter the License type (Windows_Server or Windows_Client)

# Identity variables

$domainname = Read-Host "Enter the domain where you want to join the host" # Enter your domain name
$localuser = Read-Host "Enter a local username" # Enter a local password
$localuserpwd = Read-Host "Enter a local password" # Enter a local password
$domainadminuser = Read-Host "Enter a domain admin user" # Enter a domain admin user
$domainadminpassword = Read-Host "Enter a domain admin password" # Enter a domain admin password

# Virtual Network Variables

$VirtualNetwork = Get-AzVirtualnetwork | Out-GridView -Title "Select the virtual network where you want to deploy this virtual machine" -PassThru
$Subnet = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $VirtualNetwork  | Out-GridView -Title "Select the subnet" -PassThru
$subnetid = $subnet.Id

# Monitoring Variables

$omsworkspace = Get-AzOperationalInsightsWorkspace | Out-GridView -Title "Select the OMS workspace" -PassThru

# Azure Virtual Desktop variables

$hostpool = Get-AzWvdHostPool | Out-GridView -Title "Select the hostpool where you want to deploy your host" -PassThru
$hostpoolresource = Get-AzResource -ResourceId $hostpool.Id
$registrationinfo = Get-AzWvdRegistrationInfo -ResourceGroupName $hostpoolresource.ResourceGroupName -HostPoolName $hostpool.Name
If (!($registrationinfo.Token)) {
    $registrationinfo = New-AzWvdRegistrationInfo -ResourceGroupName $hostpoolresource.ResourceGroupName -HostPoolName $hostpool.Name -ExpirationTime $((get-date).ToUniversalTime().AddDays(1).ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ'))
}

#endregion

#region ARM deployment

Write-host "Retrieving ARM template and template parameter files"
$armfile = Join-Path -Path "." -ChildPath 'imagemanagement' -AdditionalChildPath "arm","avd","host", "azuredeploy.json" | Get-Item
$armparamfile = Join-Path -Path "." -ChildPath 'imagemanagement' -AdditionalChildPath "arm","avd","host", "azuredeploy.parameters.json" | Get-Item

Write-host "Setting arm template parameter file variables"
$armparamobject = Get-Content $armparamfile.FullName | ConvertFrom-Json -AsHashtable

$armparamobject.parameters

$armparamobject.parameters.LocalAdminUser.value = $localuser
$armparamobject.parameters.Registrationtoken.value = $registrationinfo.Token
$armparamobject.parameters.LocalAdminPassword.value = $localuserpwd
$armparamobject.parameters.omsworkspaceresourceid.value = $omsworkspace.ResourceId
$armparamobject.parameters.WVDCount.value = [int]$vmcount
$armparamobject.parameters.WVDOU.value = ""
$armparamobject.parameters.SubnetId.value = $subnetid
$armparamobject.parameters.WVDVMOffset.value = [int]$vmoffset
$armparamobject.parameters.WVDSeries.value = $vmsize
$armparamobject.parameters.galleryImageVersionName.value = $imagegalleryinfo.Name
$armparamobject.parameters.galleryName.value = $imagegallery.Name
$armparamobject.parameters.Domainname.value = $domainname
$armparamobject.parameters.WVDPrefix.value = $vmprefix
$armparamobject.parameters.WVDVMStorageType.value = $vmstorage
$armparamobject.parameters.DomainAdminUpn.value = $domainadminuser
$armparamobject.parameters.galleryImageDefinitionName.value = $imagegallerydefinitioninfo.Name
$armparamobject.parameters.DomainAdminPassword.value = $domainadminpassword
$armparamobject.parameters.hostpoolName.value = $hostpool.Name

$parameterobject = @{ }
$armparamobject.parameters.keys | ForEach-Object { $parameterobject[$_] = $armparamobject.parameters[$_]['value'] }

Write-host "Deployment SPOKEvm-${vmprefix}-${vmoffset}-${vmcount} started "
$Deploy_SPOKEvm = New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroup -Name "SPOKEvm-${vmprefix}-${vmoffset}-${vmcount}" -TemplateFile $armfile.FullName -TemplateParameterObject $parameterobject
Write-host "Deployment SPOKEvm-${vmprefix}-${vmoffset}-${vmcount} complete "

#endregion
