# Variables




# Retrieve Shared Image Gallery Details

$imagegallery = Get-AzGallery | Out-GridView -Title "Select the SIG you want to use" -PassThru
$imagegallerydefinitioninfo = Get-AzGalleryImageDefinition -GalleryName $imagegallery.Name -ResourceGroupName $imagegallery.ResourceGroupName | Out-GridView -Title "Select the SIG Definition" -PassThru
$imagegalleryinfo = Get-AzGalleryImageVersion -GalleryName $imagegallery.Name -ResourceGroupName $imagegallery.ResourceGroupName -GalleryImageDefinitionName $imagegallerydefinitioninfo.Name
$defaultscripturi = "https://aspexlandingzones.blob.core.windows.net/aib/win2022_preview_proplus_clean.ps1?sp=r&st=2021-05-05T07:19:18Z&se=2030-06-05T15:19:18Z&spr=https&sv=2020-02-10&sr=b&sig=%2FeOvuJkollmOrihPbQkhszQLBaoYnVQZBA04qnoyztU%3D"

$imageversion = "1.0.7"

$ManagedIdentity = Get-AzUserAssignedIdentity -ResourceGroupName $imagegallery.ResourceGroupName | Out-GridView -Title "Please select the User Assigned Identity" -PassThru

$armfile = Join-Path "." -ChildPath "ImageManagement" -AdditionalChildPath  "arm", "aib", "azuredeploy.json" | Get-Item
$armparamfile = Join-Path "." -ChildPath "ImageManagement" -AdditionalChildPath  "arm","aib", "azuredeploy.parameters.json" | Get-Item

$armparamobject = Get-Content $armparamfile.FullName | ConvertFrom-Json -AsHashtable
$armparamobject.parameters.ScriptUri.value = $defaultscripturi
$armparamobject.parameters.SigResourceId.value = $imagegallery.Id
$armparamobject.parameters.SigImageDefinition.value = $imagegallerydefinitioninfo.Name
$armparamobject.parameters.SigImageVersion.value = $imageversion
$armparamobject.parameters.UserAssignedId.value = $ManagedIdentity.Id
$armparamobject.parameters.SigSourceImageID.value = $imagegalleryinfo.Id

$bogusparameterobject = @{ }
$armparamobject.parameters.keys | ForEach-Object { $bogusparameterobject[$_] = $armparamobject.parameters[$_]['value'] }
$Deploy_HUBWVDImageTemplate = New-AzResourceGroupDeployment -ResourceGroupName $imagegallery.ResourceGroupName -Name "HUBWVDImageTemplate2" -TemplateFile $armfile -TemplateParameterObject $bogusparameterobject

$imageTemplateName = "WinSrv2022Datacenter_1.0.7"
# Start Build

Start-AzImageBuilderTemplate -ResourceGroupName $imagegallery.ResourceGroupName -Name $imageTemplateName

$getStatus=$(Get-AzImageBuilderTemplate -ResourceGroupName $imagegallery.ResourceGroupName -Name $imageTemplateName)

# this shows all the properties
$getStatus | Format-List -Property *

# these show the status the build
$getStatus.LastRunStatusRunState 
$getStatus.LastRunStatusMessage
$getStatus.LastRunStatusRunSubState


