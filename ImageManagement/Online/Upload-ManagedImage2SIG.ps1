# Notes: In the Upload-VHD.ps1 script we have uploaded our image to a managed image, this script will copy the image to a Shared Image Gallery

#region Variables to define our Image

$ImageDefinitionName = "WinSrv2022Datacenter"
$ImageDefinitionPublisher = "microsoftwindowsserver"
$ImageDefinitionOffer = "microsoftserveroperatingsystems-previews"
$ImageDefinitionSKU = "windows-server-2022"

#endregion

#region Retrieve any existing shared Imag Galleries

$gallery = Get-AzGallery | Out-GridView -Title "Select the SIG you want to use" -PassThru
if ($gallery) {
Write-Host "You have selected the following image gallery $($gallery.name)" 
}
else {
Write-Host "You did not select a SIG, or no SIG is available, please create SIG first."
Write-Host "You can run the following PowerShell example to create a new SIG"
Write-Host '$SIGrg = New-AzResourceGroup -Location "westeurope" -Name "temp-sig-rg"' -ForegroundColor Cyan
Write-Host '$gallery = New-AzGallery -ResourceGroupName $SIGrg.ResourceGroupName -Name "tempsig" -Location "westeurope" -Description "temporary sig"' -ForegroundColor Cyan

}

#endregion

#region Create new Gallery Definition

$imageDefinition = New-AzGalleryImageDefinition `
   -GalleryName $gallery.Name `
   -ResourceGroupName $gallery.ResourceGroupName `
   -Location $gallery.Location `
   -Name $ImageDefinitionName `
   -OsState generalized `
   -OsType Windows `
   -Publisher $ImageDefinitionPublisher `
   -Offer $ImageDefinitionOffer `
   -Sku $ImageDefinitionSKU

#endregion

#region Retrieve the Managed Image

$managedImage = Get-AzImage | Out-GridView -Title "Select the Image you want to upload to the gallery" -PassThru

#endregion

#region Create new image version in SIG

$region1 = @{Name='West Europe';ReplicaCount=1}
$region2 = @{Name='North Europe';ReplicaCount=2}
$targetRegions = @($region1,$region2)
$job = $imageVersion = New-AzGalleryImageVersion `
   -GalleryImageDefinitionName $imageDefinition.Name `
   -GalleryImageVersionName '1.0.0' `
   -GalleryName $gallery.Name `
   -ResourceGroupName $imageDefinition.ResourceGroupName `
   -Location $imageDefinition.Location `
   -TargetRegion $targetRegions  `
   -SourceImageId $managedImage.Id.ToString() `
   -PublishingProfileEndOfLifeDate '2021-12-31' `
   -asJob

#endregion

#region Verify deployment state

   $job.State

#endregion

#region Delete Managed Image
<#

Remove-AzImage `
   -ImageName $managedImage.Name `
   -ResourceGroupName $managedImage.ResourceGroupName

#>
#endregion
