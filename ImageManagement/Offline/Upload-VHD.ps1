#region Variables

$VMname = Read-Host "Enter a VM name"
$path = "C:\VMs\vm22\Virtual Hard Disks"
$iso = "C:\Temp\Windows_InsiderPreview_Server_vNext_en-us_20344.iso"
#endregion


#region cOnvert the disk to a fixed size

$vhdsizeBytesFooter = "136365212160"


Convert-VHD -Path "$($path)\$($vmname).vhdx" -DestinationPath "$($path)\$($vmname)-osdisk.vhdx" -VHDType Fixed 
Resize-VHD -Path "$($path)\$($vmname)-osdisk.vhdx" -SizeBytes $vhdsizeBytesFooter

#endregion

#region upload vhd

$rgname = "hub-weu-management-rg"
$diskname = "winsrv2022tpl"


$diskconfig = New-AzDiskConfig -SkuName 'Standard_LRS' -OsType 'Windows' -UploadSizeInBytes $vhdsizeBytesFooter -Location 'westeurope' -CreateOption 'Upload' -HyperVGeneration '1'

New-AzDisk -ResourceGroupName $rgname -DiskName $diskname -Disk $diskconfig

$diskSas = Grant-AzDiskAccess -ResourceGroupName $rgname -DiskName $diskname -DurationInSecond 86400 -Access 'Write'
$disk = Get-AzDisk -ResourceGroupName $rgname -DiskName $diskname

AzCopy.exe copy "$($path)\$($vmname)-osdisk.vhdx" $diskSas.AccessSAS --blob-type PageBlob