#This script is intended to run on the machine you are going to sysprep and capture as a local VHD(x)

#region VM prep


function PrepareVM {
    
    Write-host "Performing Windows File System Check"
    sfc.exe /scannow
    
    Write-host "Displaying Persistent Routes"
    $routes = route.exe print

    Write-Host "Removing Static Routes"
    #route.exe delete *
    
    Write-Host "Removing WinHTTP proxy"
    netsh.exe winhttp reset proxy
    
    Write-Host "Configuring SAN policy"
    start-process diskpart.exe -ArgumentList "san policy=onlineall  exit"
    
    Write-Host "Configuring time zone"
    Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation -Name RealTimeIsUniversal -Value 1 -Type DWord -Force
    Set-Service -Name w32time -StartupType Automatic
    
    Write-Host "Set powerprofile to high performance"
    powercfg.exe /setactive SCHEME_MIN
    
    Write-Host "Setting default temp variables"
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment' -Name TEMP -Value "%SystemRoot%\TEMP" -Type ExpandString -Force
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment' -Name TMP -Value "%SystemRoot%\TEMP" -Type ExpandString -Force
    
    Write-host "Checking windows services"
    Get-Service -Name BFE, Dhcp, Dnscache, IKEEXT, iphlpsvc, nsi, mpssvc, RemoteRegistry | Where-Object StartType -ne Automatic | Set-Service -StartupType Automatic
    Get-Service -Name Netlogon, Netman, TermService | Where-Object StartType -ne Manual | Set-Service -StartupType Manual
    
    Write-Host "Setting remote access settings"
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections -Value 0 -Type DWord -Force
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services' -Name fDenyTSConnections -Value 0 -Type DWord -Force
    
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\Winstations\RDP-Tcp' -Name PortNumber -Value 3389 -Type DWord -Force
    
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\Winstations\RDP-Tcp' -Name LanAdapter -Value 0 -Type DWord -Force
    
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name UserAuthentication -Value 1 -Type DWord -Force
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name SecurityLayer -Value 1 -Type DWord -Force
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name fAllowSecProtocolNegotiation -Value 1 -Type DWord -Force
    
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services' -Name KeepAliveEnable -Value 1  -Type DWord -Force
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services' -Name KeepAliveInterval -Value 1  -Type DWord -Force
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\Winstations\RDP-Tcp' -Name KeepAliveTimeout -Value 1 -Type DWord -Force
    
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services' -Name fDisableAutoReconnect -Value 0 -Type DWord -Force
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\Winstations\RDP-Tcp' -Name fInheritReconnectSame -Value 1 -Type DWord -Force
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\Winstations\RDP-Tcp' -Name fReconnectSame -Value 0 -Type DWord -Force
    
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\Winstations\RDP-Tcp' -Name MaxInstanceCount -Value 4294967295 -Type DWord -Force
    
    if ((Get-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp').Property -contains 'SSLCertificateSHA1Hash') {
        Remove-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name SSLCertificateSHA1Hash -Force
    }
    Write-Host "Configuring Firewall Rules"
    
    Set-NetFirewallProfile -Profile Domain, Public, Private -Enabled True
    
    Enable-PSRemoting -Force
    Set-NetFirewallRule -DisplayName 'Windows Remote Management (HTTP-In)' -Enabled True
    
    Set-NetFirewallRule -DisplayGroup 'Remote Desktop' -Enabled True
    
    Set-NetFirewallRule -DisplayName 'File and Printer Sharing (Echo Request - ICMPv4-In)' -Enabled True
    
    New-NetFirewallRule -DisplayName AzurePlatform -Direction Inbound -RemoteAddress 168.63.129.16 -Profile Any -Action Allow -EdgeTraversalPolicy Allow
    New-NetFirewallRule -DisplayName AzurePlatform -Direction Outbound -RemoteAddress 168.63.129.16 -Profile Any -Action Allow
    

}

function FinalCheckVM {
    
    
    Write-host "Checking Boot Configuration Data Settings"
    
    bcdedit.exe /set "{bootmgr}" integrityservices enable
    bcdedit.exe /set "{default}" device partition=C:
    bcdedit.exe /set "{default}" integrityservices enable
    bcdedit.exe /set "{default}" recoveryenabled Off
    bcdedit.exe /set "{default}" osdevice partition=C:
    bcdedit.exe /set "{default}" bootstatuspolicy IgnoreAllFailures
    
    #Enable Serial Console Feature
    bcdedit.exe /set "{bootmgr}" displaybootmenu yes
    bcdedit.exe /set "{bootmgr}" timeout 5
    bcdedit.exe /set "{bootmgr}" bootems yes
    bcdedit.exe /ems "{current}" ON
    bcdedit.exe /emssettings EMSPORT:1 EMSBAUDRATE:115200
    
    
    Write-host "Enabling dump log"
    # Set up the guest OS to collect a kernel dump on an OS crash event
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl' -Name CrashDumpEnabled -Type DWord -Force -Value 2
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl' -Name DumpFile -Type ExpandString -Force -Value "%SystemRoot%\MEMORY.DMP"
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl' -Name NMICrashDump -Type DWord -Force -Value 1
    
    # Set up the guest OS to collect user mode dumps on a service crash event
    $key = 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting\LocalDumps'
    if ((Test-Path -Path $key) -eq $false) { (New-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting' -Name LocalDumps) }
    New-ItemProperty -Path $key -Name DumpFolder -Type ExpandString -Force -Value 'C:\CrashDumps'
    New-ItemProperty -Path $key -Name CrashCount -Type DWord -Force -Value 10
    New-ItemProperty -Path $key -Name DumpType -Type DWord -Force -Value 2
    Set-Service -Name WerSvc -StartupType Manual
    
    Write-host "Setting WMI"
    
    winmgmt.exe /verifyrepository
    
    Write-Host "Checking services listening on port 3389"
    
    netstat.exe -anob
    
    get-appxpackage | Where-Object { $_.Name -like "*Edge*" } | Remove-AppxPackage
    
    
}
    

Write-Host "Starting Prepare VM phase" -ForegroundColor Green
PrepareVM
Write-Host "Starting Final Check VM phase" -ForegroundColor Green
FinalCheckVM
Write-Host "Script complete ready for sysprep" -ForegroundColor Green

