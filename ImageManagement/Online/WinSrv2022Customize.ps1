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

#region FSLogix Install

try {
    $downloaduri = "https://aka.ms/fslogix_download"
    $selfextracter = "FSLogix_Apps.zip"
    $installer = "FSLogixAppsSetup.exe"
    $appruleinstaller = "FSLogixAppsRuleEditorSetup.exe"
    
    Write-Host "FSLogix: Downloading the latest release from $($downloaduri.Split("?")[0])"
    Invoke-WebRequest -Uri $DownloadUri -OutFile $selfextracter
    Write-Host "FSLogix: Downloaded"
    
    Write-Host "FSLogix: Extracting"
    $Extractstatus = Expand-Archive -Path $selfextracter -DestinationPath "FSLogix" -Force
    Write-Host "FSLogix: Extracted with statuscode $($Extractstatus.ExitCode)"
    
    Write-Host "FSLogix: Installing"
    $Installstatus = Start-Process -FilePath "FSLogix/x64/Release//$($installer)" -ArgumentList @('/q','/w') -Wait -Passthru
    Write-Host "FSLogix: Installed with statuscode $($Installstatus.ExitCode)"

    If($Installstatus.ExitCode -ne 0 -and $Installstatus.ExitCode -ne 3010)
    {
        Write-Error "FSLogix: Install failed"
        Throw $Installstatus.ExitCode
    }
    
    Write-Host "FSLogixAppRuleEditor: Installing"
    $Installstatus = Start-Process -FilePath "FSLogix/x64/Release//$($appruleinstaller)" -ArgumentList @('/q','/w') -Wait -Passthru
    Write-Host "FSLogixAppRuleEditor: Installed with statuscode $($Installstatus.ExitCode)"

    If($Installstatus.ExitCode -ne 0 -and $Installstatus.ExitCode -ne 3010)
    {
        Write-Error "FSLogixAppRuleEditor: Install failed"
        Throw $Installstatus.ExitCode
    }
}
catch {
    Write-Host "FSLogix: Failed software installation with error:"
    $error
}

#endregion