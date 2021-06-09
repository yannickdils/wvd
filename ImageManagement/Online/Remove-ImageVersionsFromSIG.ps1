#NOTE: This script can be used to cleanup obsolete image versions in your shared image gallery

#region shared image gallery details

$imagegallery = Get-AzGallery | Out-GridView -Title "Select the SIG you want to use" -PassThru
$imagegallerydefinitioninfo = Get-AzGalleryImageDefinition -GalleryName $imagegallery.Name -ResourceGroupName $imagegallery.ResourceGroupName | Out-GridView -Title "Select the SIG Definition" -PassThru
$imagegalleryinfo = Get-AzGalleryImageVersion -GalleryName $imagegallery.Name -ResourceGroupName $imagegallery.ResourceGroupName -GalleryImageDefinitionName $imagegallerydefinitioninfo.Name | Out-GridView -Title "Select the SIG Image Versions you want to delete" -OutputMode Multiple

#endregion

#region delete image versions

foreach ($imageversion in $imagegalleryinfo)
{
Write-Host "Removing $($imageversion.name) from $($imagegallerydefinitioninfo.Name)" -ForegroundColor Red
    Remove-AzGalleryImageVersion -GalleryName $imagegallery.Name -GalleryImageDefinitionName $imagegallerydefinitioninfo.Name -Name $imageversion.Name -ResourceGroupName $imageversion.ResourceGroupName -force -AsJob

}
#endregion