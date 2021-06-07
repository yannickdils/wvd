#region variables
$imagegallery = Get-AzGallery | Out-GridView -Title "Select the SIG you want to use" -PassThru
$imagegallerydefinitioninfo = Get-AzGalleryImageDefinition -GalleryName $imagegallery.Name -ResourceGroupName $imagegallery.ResourceGroupName | Out-GridView -Title "Select the SIG Definition" -PassThru
$imagegalleryinfo = Get-AzGalleryImageVersion -GalleryName $imagegallery.Name -ResourceGroupName $imagegallery.ResourceGroupName -GalleryImageDefinitionName $imagegallerydefinitioninfo.Name | Out-GridView -Title "Select the SIG Image Version" -PassThru

$MyImage = $imagegalleryinfo 
$ResourceGroup = $MyImage.ResourceGroupName
$vmprefix = "rdshost2022" # Enter the virtual machine prefix (something like wvd, dc, app)
$vmsize = "Standard_D4s_v3"
$vmcount = "1" # Enter the amount of virtual machine you like
$vmoffset = "0" # Enter the start number of your virtual machine
$vmstorage = "Premium_LRS" #Enter the storage type
$localuser = "thebossman" # Enter a local username
$localuserpwd = Read-Host "Enter a local password" # Enter a local password
$VirtualNetwork = Get-AzVirtualnetwork | Out-GridView -Title "Select the virtual network where you want to deploy this virtual machine" -PassThru
$Subnet = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $VirtualNetwork  | Out-GridView -Title "Select the subnet" -PassThru
$subnetid = $subnet.Id
$vmlicensetype = "Windows_Server"
$imagereference = @{"id" = $MyImage.Id }
$omsworkspace = Get-AzOperationalInsightsWorkspace | Out-GridView -Title "Select the OMS workspace" -PassThru

#endregion

#region ARM deployment

$armfile = Join-Path -Path "." -ChildPath 'imagemanagement' -AdditionalChildPath "arm","vm", "azuredeploy.json" | Get-Item
$armparamfile = Join-Path -Path "." -ChildPath 'imagemanagement' -AdditionalChildPath "arm","vm", "azuredeploy.parameters.json" | Get-Item

$armparamobject = Get-Content $armparamfile.FullName | ConvertFrom-Json -AsHashtable
$armparamobject.parameters.LocalAdminUser.value = $localuser
$armparamobject.parameters.LocalAdminPassword.value = $localuserpwd
$armparamobject.parameters.VMPrefix.value = $vmprefix
$armparamobject.parameters.VMSeries.value = $vmsize
$armparamobject.parameters.VMCount.value = [int]$vmcount
$armparamobject.parameters.VMOffset.value = [int]$vmoffset
$armparamobject.parameters.VMStorageType.value = $vmstorage
$armparamobject.parameters.SubnetId.value = $subnetid
$armparamobject.parameters.omsworkspaceresourceid.value = $omsworkspace.ResourceId
$armparamobject.parameters.licenseType.value = $vmlicensetype
$armparamobject.parameters.imageReference.value = $imagereference

$parameterobject = @{ }
$armparamobject.parameters.keys | ForEach-Object { $parameterobject[$_] = $armparamobject.parameters[$_]['value'] }

$Deploy_SPOKEvm = New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroup -Name "SPOKEvm-${vmprefix}-${vmoffset}-${vmcount}" -TemplateFile $armfile.FullName -TemplateParameterObject $parameterobject

#endregion