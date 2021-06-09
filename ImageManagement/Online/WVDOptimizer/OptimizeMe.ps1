<#####################################################################################################################################

    This Sample Code is provided for the purpose of illustration only and is not intended to be used in a production environment.
    THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED,
    INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.  We grant
    You a nonexclusive, royalty-free right to use and modify the Sample Code and to reproduce and distribute the object code form
    of the Sample Code, provided that You agree: (i) to not use Our name, logo, or trademarks to market Your software product in
    which the Sample Code is embedded; (ii) to include a valid copyright notice on Your software product in which the Sample Code
    is embedded; and (iii) to indemnify, hold harmless, and defend Us and Our suppliers from and against any claims or lawsuits,
    including attorneys’ fees, that arise or result from the use or distribution of the Sample Code.

    Microsoft provides programming examples for illustration only, without warranty either expressed or
    implied, including, but not limited to, the implied warranties of merchantability and/or fitness
    for a particular purpose.

    This sample assumes that you are familiar with the programming language being demonstrated and the
    tools used to create and debug procedures. Microsoft support professionals can help explain the
    functionality of a particular procedure, but they will not modify these examples to provide added
    functionality or construct procedures to meet your specific needs. if you have limited programming
    experience, you may want to contact a Microsoft Certified Partner or the Microsoft fee-based consulting
    line at (800) 936-5200.

    For more information about Microsoft Certified Partners, please visit the following Microsoft Web site:
    https://partner.microsoft.com/global/30000104

######################################################################################################################################>

# Removed Windows 10 OS Versions and altered scripts for Windows Server 2022
[Cmdletbinding()]
Param
(
    [Parameter()]
    [ValidateSet('Srv2022')]
    $WindowsVersion = 'Srv2022',

    [Parameter()]
    [Switch]
    $Restart

)

#Requires -RunAsAdministrator

<#
- TITLE:          Microsoft Windows 10 Virtual Desktop Optimization Script
- AUTHORED BY:    Robert M. Smith and Tim Muessig (Microsoft)
- ALTERED BY: Yannick Dils
- AUTHORED DATE:  11/19/2019
- LAST UPDATED:   07/06/2021
- PURPOSE:        To automatically apply settings referenced in the following white papers:
                  https://docs.microsoft.com/en-us/windows-server/remote/remote-desktop-services/rds_vdi-recommendations-1909

- Important:      Every setting in this script and input files are possible recommendations only,
                  and NOT requirements in any way. Please evaluate every setting for applicability
                  to your specific environment. These scripts have been tested on plain Hyper-V
                  VMs. Please test thoroughly in your environment before implementation

- DEPENDENCIES    1. On the target machine, run PowerShell elevated (as administrator)
                  2. Within PowerShell, set exectuion policy to enable the running of scripts.
                     Ex. Set-ExecutionPolicy -ExecutionPolicy RemoteSigned
                  3. LGPO.EXE (available at https://www.microsoft.com/en-us/download/details.aspx?id=55319)
                  4. LGPO database files available in the respective folders (ex. \1909, or \2004)
                  5. This PowerShell script
                  6. The text input files containing all the apps, services, traces, etc. that you...
                     may be interested in disabling. Please review these input files to customize...
                     to your environment/requirements

- REFERENCES:
https://social.technet.microsoft.com/wiki/contents/articles/7703.powershell-running-executables.aspx
https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.management/remove-item?view=powershell-6
https://blogs.technet.microsoft.com/secguide/2016/01/21/lgpo-exe-local-group-policy-object-utility-v1-0/
https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.management/set-service?view=powershell-6
https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.management/remove-item?view=powershell-6
https://msdn.microsoft.com/en-us/library/cc422938.aspx
#>

<# Categories of cleanup items:
This script is dependent on three elements:
LGPO Settings folder, applied with the LGPO.exe Microsoft app

The UWP app input file contains the list of almost all the UWP application packages that can be removed with PowerShell interactively.
The Store and a few others, such as Wallet, were left off intentionally.  Though it is possible to remove the Store app,
it is nearly impossible to get it back.  Please review the lists below and comment out or remove references to packages that you do not want to remove.
#>

#Added check if running on vm so you won't f up your local machine on accident - JETHRO
If ((get-wmiobject win32_computersystem).Model -ne "Virtual Machine") {
    Write-Warning "$($env:computername) is not a virtual machine"
    Exit 251
}

$StartTime = Get-Date
$CurrentLocation = Get-Location

write-host "Starting optimizer at $($StartTime)"

Try {
    Set-Location (Join-Path $PSScriptRoot $WindowsVersion) -ErrorAction Stop
}
Catch {
    Write-Warning "Invalid Path $(Join-Path $PSScriptRoot $WindowsVersion) - Exiting script!"
    Break
}

#region Disable, then remove, Windows Media Player including payload
Try {
    Write-Host "Disabling Windows Media Player Feature"
    Disable-WindowsOptionalFeature -Online -FeatureName WindowsMediaPlayer -NoRestart | Out-Null
    Get-WindowsPackage -Online -PackageName "*Windows-mediaplayer*" | ForEach-Object {
        Write-Host "Removeing $($_.PackageName)"
        Remove-WindowsPackage -PackageName $_.PackageName -Online -ErrorAction SilentlyContinue  -NoRestart | Out-Null
    }
}
Catch { }
#endregion

#region Begin Clean APPX Packages
# Enabled Microsoft.Windows.Photos, Microsoft.WindowsCalculator, Microsoft.MSPaint, Microsoft.GetHelp, Microsoft.Getstarted, Microsoft.MicrosoftOfficeHub, Microsoft.Office.OneNote - JETHRO
If (Test-Path .\ConfigurationFiles\AppxPackages.json) {
    $AppxPackage = Get-Content .\ConfigurationFiles\AppxPackages.json | ConvertFrom-Json
    $AppxPackage = $AppxPackage | Where-Object { $_.VDIState -eq 'Disabled' }
}

If ($AppxPackage.Count -gt 0) {
    Foreach ($Item in $AppxPackage) {
        $Package = "*$($Item.AppxPackage)*"
        Write-Host "Attempting to remove $($Item.AppxPackage) - $($Item.Description)"
        Get-AppxPackage -Name $Package | Remove-AppxPackage -ErrorAction SilentlyContinue  | Out-Null

        #Write-Verbose "`t`tAttempting to remove [All Users] $($Item.AppxPackage) - $($Item.Description)"
        #Get-AppxPackage -AllUsers -Name $Package | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue

        Write-Host "`t`tRemoving Provisioned Package $($item.AppxPackage)"
        Get-AppxProvisionedPackage -Online | Where-Object { $_.PackageName -like $Package } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null
    }
}
#endregion

#region Disable Scheduled Tasks
# This section is for disabling scheduled tasks.  If you find a task that should not be disabled
# change its "VDIState" from Disabled to Enabled, or remove it from the json completely.
# Enabled StartComponentCleanup - JETHRO
If (Test-Path .\ConfigurationFiles\ScheduledTasks.json) {
    $SchTasksList = Get-Content .\ConfigurationFiles\ScheduledTasks.json | ConvertFrom-Json
    $SchTasksList = $SchTasksList | Where-Object { $_.VDIState -eq 'Disabled' }
}
If ($SchTasksList.count -gt 0) {
    #$EnabledScheduledTasks = Get-ScheduledTask | Where-Object { $_.State -ne "Disabled" }
    Foreach ($Item in $SchTasksList) {
        #$Task = (($Item -split ":")[0]).Trim()
        Write-Host "Disabling Scheduled Task $($Item.ScheduledTask)"
        Disable-ScheduledTask -TaskName $Item.ScheduledTask -ErrorAction SilentlyContinue
        #$EnabledScheduledTasks | Where-Object { $_.TaskName -like "*$Task*" } #| Disable-ScheduledTask
    }
}
#endregion

#region Customize Default User Profile
# Apply appearance customizations to default user registry hive, then close hive file
# Changed script to only import uncommented lines + excluded microsoft.photos settings
# Added txt in 2009, just like in 2004. Json way gave issues - JETHRO
If (Test-Path .\ConfigurationFiles\DefaultUserSettings.txt) {
    $DefaultUserSettings = Get-Content .\ConfigurationFiles\DefaultUserSettings.txt
}
If ($DefaultUserSettings.count -gt 0) {
    Write-Host "Processing Default User Settings registry keys"
    Foreach ($Item in $DefaultUserSettings) {
        If (!($Item.StartsWith(";"))) {
            Start-Process C:\Windows\System32\Reg.exe -ArgumentList "$Item" -Wait
        }
    }
}
#endregion

#region Disable Windows Traces
# Removed RadioMgr -> no permissions to write this registryitem - JETHRO
# Added silentycontinue -> sometimes access denied for no reason - JETHRO
If (Test-Path .\ConfigurationFiles\Autologgers.Json) {
    $DisableAutologgers = Get-Content .\ConfigurationFiles\Autologgers.Json | ConvertFrom-Json
}

If ($DisableAutologgers.count -gt 0) {
    $DisableAutologgers = $DisableAutologgers | Where-Object { $_.Disabled -eq 'True' }
    Foreach ($Item in $DisableAutologgers) {
        Write-Host "Adding $($Item.KeyName)"
        New-ItemProperty -Path "$($Item.KeyName)" -Name "Start" -PropertyType "DWORD" -Value "0" -Force -ErrorAction SilentlyContinue | Out-Null
    }
}
#endregion

#region Local Group Policy Settings
# - This code does not:
#   * set a lock screen image.
#   * change the "Root Certificates Update" policy.
#   * change the "Enable Windows NTP Client" setting.
#   * set the "Select when Quality Updates are received" policy

if (Test-Path (Join-Path $PSScriptRoot "LGPO\LGPO.exe")) {
    Write-Host "Importing Local Group Policy Items"
    Start-Process (Join-Path $PSScriptRoot "LGPO\LGPO.exe") -ArgumentList "/g .\LGPO" -Wait
}
#endregion

#region Disable Services
# Enabled OneSyncSvc, VSS, WSearch - JETHRO
If (Test-Path .\ConfigurationFiles\Services.json) {
    $ServicesToDisable = Get-Content .\ConfigurationFiles\Services.json | ConvertFrom-Json
}

If ($ServicesToDisable.count -gt 0) {
    $ServicesToDisable = $ServicesToDisable | Where-Object { $_.VDIState -eq 'Disabled' }
    Foreach ($Item in $ServicesToDisable) {
        Write-Host "Stopping $($Item.Name) - $($Item.Description)"
        Stop-Service $Item.Name -Force -ErrorAction SilentlyContinue
        Write-Host "`t`tDisabling $($Item.Name)"
        Set-Service $Item.Name -StartupType Disabled
    }
}
#endregion

#region Network Optimization
# LanManWorkstation optimizations
Write-Host "Configuring LanManWorkstation Optimizations"
New-ItemProperty -Path "HKLM:\System\CurrentControlSet\Services\LanmanWorkstation\Parameters\" -Name "DisableBandwidthThrottling" -PropertyType "DWORD" -Value "1" -Force | Out-Null
New-ItemProperty -Path "HKLM:\System\CurrentControlSet\Services\LanmanWorkstation\Parameters\" -Name "FileInfoCacheEntriesMax" -PropertyType "DWORD" -Value "1024" -Force | Out-Null
New-ItemProperty -Path "HKLM:\System\CurrentControlSet\Services\LanmanWorkstation\Parameters\" -Name "DirectoryCacheEntriesMax" -PropertyType "DWORD" -Value "1024" -Force | Out-Null
New-ItemProperty -Path "HKLM:\System\CurrentControlSet\Services\LanmanWorkstation\Parameters\" -Name "FileNotFoundCacheEntriesMax" -PropertyType "DWORD" -Value "1024" -Force | Out-Null
New-ItemProperty -Path "HKLM:\System\CurrentControlSet\Services\LanmanWorkstation\Parameters\" -Name "DormantFileLimit" -PropertyType "DWORD" -Value "256" -Force | Out-Null

# Removed buffer size change to 4MB because this breaks the imagebuilder connection and thus imagebuilder fails - JETHRO
# NIC Advanced Properties performance settings for network biased environments
<#
Write-Host "Configuring Network Adapter Buffer Size"
Set-NetAdapterAdvancedProperty -DisplayName "Send Buffer Size" -DisplayValue 4MB
#>

<# Note that the above setting is for a Microsoft Hyper-V VM.  You can adjust these values in your environment...
by querying in PowerShell using Get-NetAdapterAdvancedProperty, and then adjusting values using the...
Set-NetAdapterAdvancedProperty command.
#>
#endregion

#region filecleanup
# ADDITIONAL DISK CLEANUP
# Delete not in-use files in locations C:\Windows\Temp and %temp%
# Also sweep and delete *.tmp, *.etl, *.evtx, *.log, *.dmp, thumbcache*.db (not in use==not needed)
# 5/18/20: Removing Disk Cleanup and moving some of those tasks to the following manual cleanup
# Removed *.log from removed extensions - Jethro

Write-Host "Removing .tmp, .etl, .evtx, thumbcache*.db files not in use"
Get-ChildItem -Path c:\ -Include *.tmp, *.dmp, *.etl, *.evtx, thumbcache*.db -File -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -ErrorAction SilentlyContinue

# Delete "RetailDemo" content (if it exits)
Write-Host "Removing Retail Demo content (if it exists)"
Get-ChildItem -Path $env:ProgramData\Microsoft\Windows\RetailDemo\* -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -ErrorAction SilentlyContinue

# Delete not in-use anything in the C:\Windows\Temp folder
Write-Host "Removing all files not in use in $env:windir\TEMP"
Remove-Item -Path $env:windir\Temp\* -Recurse -Force -ErrorAction SilentlyContinue

# Clear out Windows Error Reporting (WER) report archive folders
Write-Host "Cleaning up WER report archive"
Remove-Item -Path $env:ProgramData\Microsoft\Windows\WER\Temp\* -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path $env:ProgramData\Microsoft\Windows\WER\ReportArchive\* -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path $env:ProgramData\Microsoft\Windows\WER\ReportQueue\* -Recurse -Force -ErrorAction SilentlyContinue

# Delete not in-use anything in your %temp% folder
Write-Host "Removing files not in use in $env:TEMP directory"
Remove-Item -Path $env:TEMP\* -Recurse -Force -ErrorAction SilentlyContinue

# Clear out ALL visible Recycle Bins
Write-Host "Clearing out ALL Recycle Bins"
Clear-RecycleBin -Force -ErrorAction SilentlyContinue

# Clear out BranchCache cache
Write-Host "Clearing BranchCache cache"
Clear-BCCache -Force -ErrorAction SilentlyContinue
#endregion

Set-Location $CurrentLocation
$EndTime = Get-Date
$ScriptRunTime = New-TimeSpan -Start $StartTime -End $EndTime
Write-Host "Total Run Time: $($ScriptRunTime.Hours) Hours $($ScriptRunTime.Minutes) Minutes $($ScriptRunTime.Seconds) Seconds" -ForegroundColor Cyan

# Added deactivation of windows firewall - JETHRO
Set-NetFirewallProfile -Profile Domain, Public, Private -Enabled False
$error.Clear()

#Commented reboot -> imagebuilder takes care of reboot - JETHRO
<#
If ($Restart)
{
    Restart-Computer -Force -Confirm:$False
}
else
{
    Write-Warning "A reboot is required for all changed to take effect"
}
#>
#Add-Type -AssemblyName PresentationFramework
#$Answer = [System.Windows.MessageBox]::Show("Reboot to make changes effective?", "Restart Computer", "YesNo", "Question")
#Switch ($Answer)
#{
#    "Yes" { Write-Warning "Restarting Computer in 15 Seconds"; Start-sleep -seconds 15; Restart-Computer -Force }
#    "No" { Write-Warning "A reboot is required for all changed to take effect" }
#    Default { Write-Warning "A reboot is required for all changed to take effect" }
#}

########################  END OF SCRIPT  ########################
