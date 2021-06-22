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

#region Azure Virtual Desktop Optimizer 
    
$ImageFolder = "C:\ImageBuilder\"

If (!(Test-Path $ImageFolder)) {
    Write-Host "ImagebuilderDefault: ${ImageFolder} does not exist, creating it right now"
    New-Item $ImageFolder -ItemType Directory | Out-Null
    Write-Host "ImagebuilderDefault: ${ImageFolder} created"
}

Write-Host "ImagebuilderDefault: Starting WVDOptimizer"
Set-Location $ImageFolder
$uri = "https://github.com/yannickdils/wvd/raw/main/ImageManagement/Online/WVDOptimizer.zip"
$outputzip = "${ImageFolder}WVDOptimizer.zip"
Invoke-WebRequest -Uri $uri -OutFile $outputzip
Expand-Archive -Path $outputzip -DestinationPath $ImageFolder -Force
C:\ImageBuilder\WVDOptimizer\OptimizeMe.ps1
Write-Host "ImagebuilderDefault: Ended WVDOptimizer"
#endregion


#endregion
