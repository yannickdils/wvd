#region Variables

# Change this URL if you want other Script or Optimization actions to run
$defaultscripturi = "https://raw.githubusercontent.com/yannickdils/wvd/main/ImageManagement/Online/WinSrv2022Customize.ps1"

# Change this to the version number you want to create
$imageversion = "1.1.7"

# Retrieve Shared Image Gallery Details

$imagegallery = Get-AzGallery | Out-GridView -Title "Select the SIG you want to use" -PassThru
$imagegallerydefinitioninfo = Get-AzGalleryImageDefinition -GalleryName $imagegallery.Name -ResourceGroupName $imagegallery.ResourceGroupName | Out-GridView -Title "Select the SIG Definition" -PassThru
$imagegalleryinfo = Get-AzGalleryImageVersion -GalleryName $imagegallery.Name -ResourceGroupName $imagegallery.ResourceGroupName -GalleryImageDefinitionName $imagegallerydefinitioninfo.Name | Out-GridView -Title "Select the SIG Image Version" -PassThru

# Retrieve Managed User Identity

$ManagedIdentity = Get-AzUserAssignedIdentity -ResourceGroupName $imagegallery.ResourceGroupName | Out-GridView -Title "Please select the User Assigned Identity" -PassThru

#endregion

#region Start Create Template


# Create ARM parameters

$armfile = Join-Path "." -ChildPath "ImageManagement" -AdditionalChildPath  "arm", "aib", "azuredeploy.json" | Get-Item
$armparamfile = Join-Path "." -ChildPath "ImageManagement" -AdditionalChildPath  "arm","aib", "azuredeploy.parameters.json" | Get-Item

$armparamobject = Get-Content $armparamfile.FullName | ConvertFrom-Json -AsHashtable
$armparamobject.parameters.ScriptUri.value = $defaultscripturi
$armparamobject.parameters.SigResourceId.value = $imagegallery.Id
$armparamobject.parameters.SigImageDefinition.value = $imagegallerydefinitioninfo.Name
$armparamobject.parameters.SigImageVersion.value = $imageversion
$armparamobject.parameters.UserAssignedId.value = $ManagedIdentity.Id
$armparamobject.parameters.SigSourceImageID.value = $imagegalleryinfo.Id

$paramobject = @{ }
$armparamobject.parameters.keys | ForEach-Object { $paramobject[$_] = $armparamobject.parameters[$_]['value'] }

# Define Image Template Name

$imageTemplateName = $imagegallerydefinitioninfo.Name + "_" + $imageversion

# Deploy ARM Template

$Deploy_HUBWVDImageTemplate = New-AzResourceGroupDeployment -ResourceGroupName $imagegallery.ResourceGroupName -Name $imageTemplateName -TemplateFile $armfile -TemplateParameterObject $paramobject

#endregion

#region Start Build Template

Start-AzImageBuilderTemplate -ResourceGroupName $imagegallery.ResourceGroupName -Name $imageTemplateName -AsJob

$getStatus=$(Get-AzImageBuilderTemplate -ResourceGroupName $imagegallery.ResourceGroupName -Name $imageTemplateName)

# this shows all the properties
$getStatus | Format-List -Property *

# these show the status the build
$getStatus.LastRunStatusRunState 
$getStatus.LastRunStatusMessage
$getStatus.LastRunStatusRunSubState

#endregion