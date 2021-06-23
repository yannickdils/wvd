$locName="westeurope"
$pubName = "MicrosoftWindowsServer"
$offerName = "microsoftserveroperatingsystems-previews"
$offerName = "WindowsServer"

Get-AzVMImageOffer -Location $locName -PublisherName $pubName | Select Offer

Get-AzVMImageSku -Location $locName -PublisherName $pubName -Offer $offerName | Select Skus
$skuName = "windows-server-2022"
$skuName = "windows-server-2022-azure-edition-preview"
$version = "2016.127.20170406"
Get-AzVMImage -Location $locName -PublisherName $pubName -Offer $offerName -Skus $skuName 
