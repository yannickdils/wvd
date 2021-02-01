<#
.SYNOPSIS
    Dismount lingering FSLogix VHD(X) profiles.

.DESCRIPTION
    Dismount lingering FSLogix VHD(X) profiles.

.PARAMETER Mode
    Provide the execution mode of the script.
    Alerting : Generates an alert whenever a lingering FSLogix VHDX profile is found
    React : Tries to dismount the lingering FSLogix Profile on the host where it is attached

.PARAMETER ProfileStorageAccount
    Provide the storage account where the FSLogix profiles are located

.PARAMETER ProfileStorageAccount
    Provide the fileshare where the FSLogix profiles are located

.PARAMETER StorageAccountResourceGroupName
    Provide the resource group name of your storage account

.PARAMETER OverrideErrorActionPreference
    Provide the ErrorActionPreference setting, as descibed in about_preference_variables.
    (https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_preference_variables?view=powershell-7#erroractionpreference).
    When running locally we should use "Break" mode, which breaks in to the debugger when an error is thrown.

.EXAMPLE
    PS C:\> .\Clean-LingeringFSLogixProfiles.ps1 -Mode "Alerting" -ProfileStorageAccount "storageaccountname" -ProfileShare "profileshare" -StorageAccountResourceGroupName "resourcegroupname"

#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidateSet('alerting', 'react')]
    [string]
    $Mode,
    [Parameter(Mandatory = $true)]
    [string]
    $ProfileStorageAccount,
    [Parameter(Mandatory = $true)]
    [string]
    $ProfileShare,
    [Parameter(Mandatory = $true)]
    [string]
    $StorageAccountResourceGroupName,
    [Parameter(Mandatory = $false)]
    [string]
    $OverrideErrorActionPreference = "Break"
)

$ErrorActionPreference = $OverrideErrorActionPreference

# The following cmd retrieves your storage account details and puts it in a context variable
$context = Get-AzStorageAccount -ResourceGroupName $StorageAccountResourceGroupName -Name $ProfileStorageAccount

#region retrieve details per hostpool
# Retrieves the hostpools => Alter the script here to check for additional host pools
$hostpools = get-azwvdhostpool
foreach ($hostpool in $hostpools) {
    $wvdrg = Get-AzResource -ResourceId $hostpools.Id
    # This is tricky, so if you only need 1 host pool remove the foreach loop completely and comment the line below
    $hostpools = $hostpool


    #region gather all open files & sessions
    $OpenFiles = Get-AzStorageFileHandle -Context $Context.Context -ShareName $ProfileShare -Recursive
    $UserSessions = Get-AzWvdUserSession -HostPoolName $hostpools.Name -ResourceGroupName $wvdrg.ResourceGroupName | Select-Object ActiveDirectoryUserName, ApplicationType, SessionState, UserPrincipalName, name
    #endregion

    #region fill Open Files array
    $pathusers = @()
    foreach ($openfile in $OpenFiles) {

        If ($openfile.path) {
            #Write-host $openfile.Path
            $FilePath = $openfile.Path.Split("/")[0]
            $pathusers += $FilePath
        }
    }
    $pathusers = $pathusers | Select-Object -Unique
    #endregion

    #region fill Open Sessions array
    $sessionusers = @()
    foreach ($usersession in $UserSessions) {

        If ($usersession) {
            #Write-host $usersession
            $Username = $UserSession.ActiveDirectoryUserName.Split("\")[1]

            $sessionusers += $Username
        }
    }
    $sessionusers = $sessionusers | Select-Object -Unique
    #endregion

    #region loop through every open file and find a corresponding user session
    foreach ($pathuser in $pathusers) {
        If ($sessionusers -contains $pathuser) {
            Write-host -ForegroundColor green "Active session user: " $pathuser
        } else {
            If ($mode -eq "alerting") {
                $OpenFilesDetails = Get-AzStorageFileHandle -Context $Context.Context -ShareName $ProfileShare -Recursive | Where-Object { $_.Path -like "*$($pathuser)*" }
                # the following retrieves the virtual machine name of the lingering VHDX file
                $IPNic = ((Get-AzNetworkInterface | Where-Object { $_.IpConfigurations.PrivateIpAddress -eq $($OpenFilesDetails.ClientIp.IPAddressToString[0]) }).virtualmachine).Id
                $vmname = ($IPNic -split '/') | Select-Object -Last 1
                $VM = Get-AzVm -Name $vmname
                Write-host -ForegroundColor red "Inactive session user: $pathuser has a FSLogix mounted on the following virtual machine $vmname"
            } Else {
                $OpenFilesDetails = Get-AzStorageFileHandle -Context $Context.Context -ShareName $ProfileShare -Recursive | Where-Object { $_.Path -like "*$($pathuser)*" }
                # the following retrieves the virtual machine name of the lingering VHDX file
                $IPNic = ((Get-AzNetworkInterface | Where-Object { $_.IpConfigurations.PrivateIpAddress -eq $($OpenFilesDetails.ClientIp.IPAddressToString[0]) }).virtualmachine).Id
                $vmname = ($IPNic -split '/') | Select-Object -Last 1
                $VM = Get-AzVm -Name $vmname
                Write-host -ForegroundColor red "Inactive session user: $pathuser has a FSLogix mounted on the following virtual machine $vmname"
                # double check whether or not you want to dismount the profile
                $YesNo = Read-Host "Are you sure you want to dismount the user profile off $pathuser on the following server $vmname: Yes/No"
                If ($YesNo -eq "Yes")
                {
                    $domainupn = Read-Host "Please enter your domain admin username:"
                    $domainpwd = Read-Host "Please enter your domain admin password:"
                    $runDismount = Invoke-AzVMRunCommand -ResourceGroupName $VM.ResourceGroupName -Name $VM.Name -CommandId 'RunPowerShellScript' -ScriptPath "scripts\AzVMRunCommands\Clean-InVMLingeringFSLogixProfiles.ps1"  -Parameter @{"Upn" = "$domainupn"; "Pass" = "$domainpwd";"pathuser" = $pathuser }
                    If ($runDismount.Status -Ne "Succeeded") {
                        Write-Error "Run failed"
                    }
                    else {
                        Write-Host "FSLogix profile has been dismounted for $($pathuser) on $($vmname)"
                    }
                }
            else {
                # Exit script
                Write-Host "We are now exiting the script, you've entered the wrong option: Yes/No is required"
                Exit
            }
            }
        }
    }
    #endregion
}
#endregion
