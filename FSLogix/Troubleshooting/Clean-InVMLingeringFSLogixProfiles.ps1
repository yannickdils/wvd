param (
    [Parameter(Mandatory = $true)]
    [string]
    $pathuser,
    [Parameter(Mandatory = $true)]
    [string]
    $upn,
    [Parameter(Mandatory = $true)]
    [string]
    $pass,
    [Parameter(Mandatory = $false)]
    [string]
    $OverrideErrorActionPreference = "Break"
)

#This script is run within the virtual machine

$ziptargetfolder = "c:\troubleshooting\"
$innerscriptlocation = $ziptargetfolder + "Dismount-VHD.ps1"

If (!(Test-Path $ziptargetfolder)) {
    mkdir $ziptargetfolder
}

@"
`$ProfileNamingConvention = "Profile-" + "$pathuser"
`$Volume = Get-Volume | Where-Object { `$_.filesystemlabel -eq `$ProfileNamingConvention } | % { Get-DiskImage -DevicePath `$(`$_.Path -replace "\\`$") }
Dismount-DiskImage -ImagePath `$Volume.ImagePath
"@ | Out-File -FilePath $innerscriptlocation

$taskName = "Dismount-FSLogixProfile"
$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -NoLogo -NonInteractive -ExecutionPolicy Unrestricted -File $innerscriptlocation" -WorkingDirectory $ziptargetfolder
$Settings = New-ScheduledTaskSettingsSet -Compatibility Win8
$TaskPath = "\CustomTasks"
Register-ScheduledTask -TaskName $taskName -User $upn -Password $pass  -RunLevel Highest -Action $Action -Settings $Settings


Start-ScheduledTask -TaskName $taskName -TaskPath $TaskPath
while ((Get-ScheduledTask -TaskName $taskName).State -ne 'Ready') {
    Start-Sleep -Seconds 2
}

Unregister-ScheduledTask -TaskName $taskName -Confirm:$False
Remove-Item -Path $innerscriptlocation -Recurse -Force

