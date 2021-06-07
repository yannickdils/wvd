#This is a configuration script that needs to be run on the virtual machine



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

#region add RDS Host role
Install-WindowsFeature -Name rds-rd-server

#endregion
