#region Install Hyper-V role

$OSVersion = (Get-WmiObject -class Win32_OperatingSystem).Caption
If ($OSVersion -like "*Server*") {
    Write-Host "Working on Windows Server OS"
    Install-WindowsFeature -Name Hyper-V -IncludeAllSubFeature -IncludeManagementTools
}
else {
    Write-Host "Working on Windows Client OS"
    Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
}

#endregion

#region Import Hyper-V module

Import-Module Hyper-V

#endregion

#region Variables

# Generic Variables
$Switchname = "InternalNATSwitch"
$NatName = "InternalNETNAT"
$VMname = "ws20h2"
$VMPath = "C:\HyperV\$($VMname)"
$DownloadURI = "<link to download location>"
$InstallMedia = "<link to ISO file>"

# DHCP Scope Variables
$ScopeID = "192.168.200.0"
$startrange = "192.168.200.1"
$endrange = "192.168.200.100"
$description = "NestedScope"
$SubnetMask = "255.255.255.0"
$Gateway = "192.168.200.1"
$ServerIP = "192.168.200.2"
$AddressPrefix = "192.168.200.0/24"

#endregion

#region Create Hyper-V Virtual Switch

$VMSwitch = New-VMSwitch -Name $Switchname -SwitchType Internal
New-NetNat –Name $NatName –InternalIPInterfaceAddressPrefix $AddressPrefix

#endregion

#region Create New VM

New-VM -Name $VMname -MemoryStartupBytes "2147483648" -Path $VMPath -SwitchName $switchname -NewVHDSizeBytes 128GB -NewVHDPath "$VMPath.vhdx" 

#endregion

#region Add DVD Drive to Virtual Machine

Add-VMScsiController -VMName $VMName
Add-VMDvdDrive -VMName $VMName -ControllerNumber 1  -Path $InstallMedia

#endregion

#region Mount Installation Media

$DVDDrive = Get-VMDvdDrive -VMName $VMName | Where-Object { $_.DvdMediaType -like "ISO" }

#endregion

#region DHCP install and configuration

#Add DHCP Role to the server to provision IP addresses for your Nested virtual machines
Add-WindowsFeature -Name DHCP -IncludeAllSubFeature -IncludeManagementTools


# Add DHCP Scope and Options
$Scope = Add-DhcpServerv4Scope -StartRange $startrange -EndRange $endrange -Description $description -SubnetMask $SubnetMask -Name $description
Set-DhcpServerv4OptionValue -value $gateway -optionId 3 -ScopeId $ScopeID

#endregion

#region Assign the network adapter with an IP

Get-NetAdapter "vEthernet ($Switchname)" | New-NetIPAddress -IPAddress $startrange -AddressFamily IPv4 -PrefixLength 24

#endregion

# Once you have your VM up and running you can run this within the VM
Get-NetAdapter "Ethernet" | New-NetIPAddress -IPAddress $ServerIP  -DefaultGateway $Gateway  -AddressFamily IPv4 -PrefixLength 24
Netsh interface ip add dnsserver “Ethernet” address=8.8.8.8
