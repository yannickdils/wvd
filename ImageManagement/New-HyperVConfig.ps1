#Windows 10
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
#Windows Server
Install-WindowsFeature -Name Hyper-V -IncludeAllSubFeature -IncludeManagementTools


Import-Module Hyper-V

$Switchname = "InternalNATSwitch"
$NatName = "InternalNETNAT"
$VMname = "ws20h2"
$VMPath = "C:\HyperV\$($VMname)"

$DownloadURI = ""
$InstallMedia = ""


$VMSwitch = New-VMSwitch -Name $Switchname -SwitchType Internal
New-NetNat –Name $NatName –InternalIPInterfaceAddressPrefix “192.168.101.0/24”
New-VM -Name $VMname -MemoryStartupBytes "2147483648" -Path $VMPath -SwitchName $switchname -NewVHDSizeBytes 128GB -NewVHDPath "$VMPath.vhdx" 

# Add DVD Drive to Virtual Machine
Add-VMScsiController -VMName $VMName
Add-VMDvdDrive -VMName $VMName -ControllerNumber 1  -Path $InstallMedia

# Mount Installation Media
$DVDDrive = Get-VMDvdDrive -VMName $VMName | Where-Object {$_.DvdMediaType -like "ISO"}

# Assign the network adapter with an IP
Get-NetAdapter "vEthernet ($Switchname)" | New-NetIPAddress -IPAddress 192.168.101.1 -AddressFamily IPv4 -PrefixLength 24





#Add additional step to configure DHCP Scope
Add-WindowsFeature -Name DHCP -IncludeAllSubFeature -IncludeManagementTools
New-DHCP

#Need to be run within the hyper-v VM
Get-NetAdapter "Ethernet" | New-NetIPAddress -IPAddress 192.168.100.2 -DefaultGateway 192.168.100.1 -AddressFamily IPv4 -PrefixLength 24
Netsh interface ip add dnsserver “Ethernet” address=8.8.8.8