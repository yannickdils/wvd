$ErrorActionPreference = 'Stop'
if (-not $PSScriptRoot)
{
  $PSScriptRoot = Split-Path $MyInvocation.InvocationName
}
if ( -not $env:Path.Contains( "$PSScriptRoot;") )
{
  $env:Path = "$PSScriptRoot;$env:Path"
}

$Status = New-PackageStatus -Message 'Update Extension' -Status 'transitioning' -Name 'AmdGpuDriverWindows' -Operation 'Update'

# Read the environment, config settings and get status target
$Env = Get-Environment
$StatusFile = $Env.StatusFile

# Update AMD Driver
try
{
  $FatalError = @()

  $Status = New-PackageStatus -Message 'Enable Extension' -Status 'transitioning' -Name 'AmdGpuDriverWindows' -Operation 'Enable'

  # Read the environment, config settings and get status target
  $Env = Get-Environment
  $StatusFile = $Env.StatusFile

  # Check if the driver is installed
  $Driver = Set-DriverInfo
  $DriverVersion = Check-Driver $Driver

  if ( $Null -ne $DriverVersion )
  {
    $Message = "AMD GPU driver version $DriverVersion detected. Already installed. Trying to upgrade"
    $Status | Add-PackageSubStatus -Message $Message -Status 'success' | Out-Null

    #region new driver download and update
    # Select the driver to install
    if ($Env.DriverUrl -eq $null)
    {
      Get-DriverDownloadInfo $Driver
    }
    else
    {
      $Driver.Url = $Env.DriverUrl
    }
     # Download Driver archive
    $source = $Driver.Url
    $Driver.ArchiveFile = $Driver.Url.Substring($Driver.Url.LastIndexOf("/") + 1)
    $dest = "$($Driver.InstallFolder)\$($Driver.ArchiveFile)"

    . download.ps1
    Get-DriverFile $source $dest
      #install the driver from the downloaded package
    $argumentList = "/S /D=" + $Driver.ExpandFolder
    $p = Start-Process -FilePath $dest -ArgumentList $argumentList -PassThru -Wait

    # check if installation process was successful
    if ($p.ExitCode -eq 0)
    {
      $Status | Add-PackageSubStatus -Message "Installation process complete." -Status 'success' -Code $p.ExitCode | Out-Null
      $Status | Set-PackageStatus -Status 'success'
      Write-Host "Installation process complete. Code: $($p.ExitCode)"
    }
    else
    {
      $Status | Add-PackageSubStatus -Message "Installation of $dest failed!" -Status 'error' -Code $p.ExitCode | Out-Null
      $Status | Set-PackageStatus -Status 'error'
      Write-Host "Installation of the driver package failed! Code: $($p.ExitCode)"
    }
    #endregion

    Write-Host $Message

    $Status | Set-PackageStatus -Status 'success'
  }
  else
  {
    $Status | Add-PackageSubStatus -Message "AMD GPU driver not detected. Attempting to install." -Status 'success' | Out-Null

    # Select the driver to install
    if ($Env.DriverUrl -eq $null)
    {
      Get-DriverDownloadInfo $Driver
    }
    else
    {
      $Driver.Url = $Env.DriverUrl
    }

    # Download Driver archive
    $source = $Driver.Url
    $Driver.ArchiveFile = $Driver.Url.Substring($Driver.Url.LastIndexOf("/") + 1)
    $dest = "$($Driver.InstallFolder)\$($Driver.ArchiveFile)"

    . download.ps1
    Get-DriverFile $source $dest

    #install the driver from the downloaded package
    $argumentList = "/S /D=" + $Driver.ExpandFolder
    $p = Start-Process -FilePath $dest -ArgumentList $argumentList -PassThru -Wait

    # check if installation process was successful
    if ($p.ExitCode -eq 0)
    {
      $Status | Add-PackageSubStatus -Message "Installation process complete." -Status 'success' -Code $p.ExitCode | Out-Null
      $Status | Set-PackageStatus -Status 'success'
      Write-Host "Installation process complete. Code: $($p.ExitCode)"
    }
    else
    {
      $Status | Add-PackageSubStatus -Message "Installation of $dest failed!" -Status 'error' -Code $p.ExitCode | Out-Null
      $Status | Set-PackageStatus -Status 'error'
      Write-Host "Installation of the driver package failed! Code: $($p.ExitCode)"
    }
  }
}
catch [NotSupportedException]
{
  $Message = $_.ToString()
  Write-Host $Message
  $Status | Add-PackageSubStatus -Message $Message -Status 'error' -Code 100 | Out-Null
  $Status | Set-PackageStatus -Status 'error'
  $Status | Save-PackageStatus $StatusFile
  exit 0
}
catch
{
  $FatalError += $_
  Write-Host -ForegroundColor Red ($_ | Out-String)
  exit $FatalError.Count
}
finally
{
  $Status | Save-PackageStatus $StatusFile
}
