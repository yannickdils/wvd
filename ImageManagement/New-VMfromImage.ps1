#region variables

$MyImage = Get-AzImage | Select Name, Location, ResourceGroupName, HyperVGeneration, Id |Out-GridView -Title "Select the Image you want to deploy" -PassThru
$ResourceGroup = $MyImage.ResourceGroupName
$vmprefix = "dc2022" # Enter the virtual machine prefix (something like wvd, dc, app)
$vmsize = "Standard_D4s_v3"
$vmcount = "1" # Enter the amount of virtual machine you like
$vmoffset = "1" # Enter the start number of your virtual machine
$vmstorage = "Premium_LRS" #Enter the storage type
$localuser = "thebossman" # Enter a local username
$localuserpwd = "YvsVaP9#FLRDtdU8*KAE#237" # Enter a local password
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