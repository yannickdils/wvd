#region supporting functions
function confirm-path {
    Param ([string]$templocation)
    $Path = Test-Path $templocation
    If ($Path -eq $true) {
        Write-Host "The $($templocation) path already exists, no need to create one" -ForegroundColor Cyan
    } Else {
        Write-host "We are creating a temp directory $($templocation)" -ForegroundColor Cyan
        $DontShow = mkdir $templocation
    }
}
#endregion

#region Variables

# Virtual Machine Name or Virtual Disk name (without .vhd(x))
$VMname = Read-Host "Enter a VM name"
# File location of  your VHD(X) files
$path = "F:\"
# Download Location for AzCopy
$templocation = "C:\Temp"
# Diskname of the converted disk (local)
$UploadDiskName = "tpldisk"
# Resource Group Name where you will be uploading the managed disk
$rgname = "yannickd-win2022-wvd"
# Diskname of the Azure Managed Disk (Azure)
$diskname = "ws2022templatediskv05"
# Image Name of the Azure Managed Image you want to create
$imageName = "WS2022_Image"
# Region or Location
$location = "westeurope"
#endregion

#region prerequisites

#Download AZCopy

$AzCopyWin64DownloadURI = "https://aka.ms/downloadazcopy-v10-windows"
$AzCopyDownloadLocation = "$templocation\AzCopy.zip"
$AZCopyLocation = "$templocation\AzCopy"
$Logfile = $templocation + "\logfile.txt"
confirm-path $templocation

(New-Object System.Net.WebClient).DownloadFile($AzCopyWin64DownloadURI, $AzCopyDownloadLocation)
confirm-path $AZCopyLocation
$shell = New-Object -ComObject Shell.Application
$zipFile = $shell.NameSpace($AzCopyDownloadLocation)
$destinationFolder = $shell.NameSpace("$AZCopyLocation")

$copyFlags = 0x00
$copyFlags += 0x04 # Hide progress dialogs
$copyFlags += 0x10 # Overwrite existing files

$destinationFolder.CopyHere($zipFile.Items(), $copyFlags)
$AzCopyPath = dir $AZCopyLocation
$AzCopyDirectory = $AZCopyLocation + "\" + $AzCopyPath.Name
$env:Path += ";$($AzCopyDirectory)"         

#Download / Import AZPoShCmdlets
Install-Module Az -force
Import-Module Az

#Import Hyper-V PoshCMDlets
Import-Module Hyper-V



#endregion

#region Convert the disk to a fixed size and vhd format

#Resizing via Hyper-V manager to 128GB and VHD did the trick and pointed out that we need the size in bytes below. Change the size if you require a different OS disk size.
$128GB = "137438953472"
$vhdsizeBytesFooter = $128GB

# Convert-VHD will convert the existing Dynamic VHDX file into a Fixed VHD file
Convert-VHD -Path "$($path)\$($vmname).vhdx" -DestinationPath "$($path)\$($vmname)-$($UploadDiskName).vhd" -VHDType Fixed

# Resize-VHD will resize the VHD file to the size defined in the previous variable, this must be a Multiple of MiB, 137438953472 is the size in bytes required to upload a 128GB disk
Resize-VHD -Path "$($path)\$($vmname)-$($UploadDiskName).vhd" -SizeBytes $vhdsizeBytesFooter

# Since there is a difference between Filesize, Size & DiskSize we get the latest lenght of the disk we have just resized. This size will be re-used when creating the disk in Azure
$SourceSize = (Get-Item "$($path)\$($vmname)-$($UploadDiskName).vhd").Length

#endregion

#region Create Target Disk in Azure

# Login to your Azure Account
Login-AzAccount

# Select your Azure Subscription
$Subscription = Get-AzSubscription | Out-GridView -Title "Select the Azure Subscription you want to use" -PassThru
Set-AzContext -Subscription $Subscription.id

# Select your Azure Resource Group
$ResourceGroup = Get-AzResourceGroup | Select ResourceGroupName,Tags,Location | Out-GridView -title "Select the Azure Resource Group you want to use" -PassThru
$rgname = $ResourceGroup.ResourceGroupName

# Configure the Target Disk on Azure

$diskconfig = New-AzDiskConfig -SkuName 'Standard_LRS' -OsType 'Windows' -UploadSizeInBytes "$($SourceSize)" -Location 'westeurope' -CreateOption 'Upload' -HyperVGeneration '1'
New-AzDisk -ResourceGroupName $rgname -DiskName $diskname -Disk $diskconfig

#endregion

#region Upload Disk to Azure

# Generate a SAS token with Write Permissions and upload with AZ Copy
$diskSas = Grant-AzDiskAccess -ResourceGroupName $rgname -DiskName $diskname -DurationInSecond 86400 -Access 'Write'
AzCopy.exe copy "$($path)\$($vmname)-$($UploadDiskName).vhd" $diskSas.AccessSAS --blob-type PageBlob

#endregion

#region Create Image from Disk

# Select the template Disk that you have uploaded
$Disk = Get-AzDisk | where-object {$_.ResourceGroupName -like "$($rgName)"} | Out-GridView -PassThru

# Retrieve the Disk ID of the template Disk
$diskID = $disk.Id

# Create a new image config
$imageConfig = New-AzImageConfig -Location $location

# Set the Azure Image OS Disk configuration
$imageConfig = Set-AzImageOsDisk -Image $imageConfig -OsState Generalized -OsType Windows -ManagedDiskId $diskID 

# Revoke Disk Access
Revoke-AzDiskAccess -ResourceGroupName $rgname -DiskName $diskname 

# Create the actual new Azure Image
New-AzImage -ImageName $imageName -ResourceGroupName $rgName -Image $imageConfig

#endregion