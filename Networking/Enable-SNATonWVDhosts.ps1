#region clear variables & in memory parameters
$slb = $null
$vm = $null
$NI = $null
$natrules = $null
$NIConfig = $null
$ELBPurpose =  $null
$ELBlocation = $null
$SKU =  $null
#endregion

#region input variables
$ELBPurpose = "enter the purpose of your loadbalancer (ex. wvd)"
$ELBlocation = "enter the location of your loadbalancer (ex. westeurope)"
$SKU = "enter the SKU of your loadbalancer (ex. standard)"
$ELBResourceGroup =  "enter the resource group name of your loadbalancer (ex. prd-network-rg)"
#endregion

#region naming convention
$ELBconvention = "-elb"
$PIPconvention = "-pip"
$FrontEndConvention = "-fep"
$BackEndConvention = "-bep"
$OutboundRuleConvention = "-obr"

$ELBname = $ELBPurpose + $ELBconvention
$ELBpip = $ELBname + $PIPconvention
$ELBFrontEndName = $ELBname + $FrontEndConvention
$ELDBackEndPoolName = $ELBname + $BackEndConvention
$ELBOutboundRulename = $ELBname + $OutboundRuleConvention
#endregion

#region loadbalancer deployment

# Step 1: Create a new static public IP address
$publicip = New-AzPublicIpAddress -ResourceGroupName $ELBResourceGroup -name $ELBpip -Location $ELBlocation -AllocationMethod Static -Sku $SKU

# Step 2: Create a new front end pool configuration and assign the public IP
$frontend = New-AzLoadBalancerFrontendIpConfig -Name $ELBFrontEndName -PublicIpAddress $publicip

# Step 3: Create a new back end pool configuration
$backendAddressPool = New-AzLoadBalancerBackendAddressPoolConfig -Name $ELDBackEndPoolName


# Step 4: Create the actual load balancer
$slb = New-AzLoadBalancer -Name $ELBname -ResourceGroupName $ELBResourceGroup -Location $ELBlocation -FrontendIpConfiguration $frontend -BackendAddressPool $backendAddressPool -Sku $SKU

# Step 5: Assign the back end VMs to the loadbalancer
$VMs = Get-AzVM | Out-GridView -PassThru -Title "Select your WVD hosts"

foreach ($vm in $VMs) {
    $NI = Get-AzNetworkInterface | Where-Object { $_.name -like "*$($VM.name)*" }
    $NI.IpConfigurations[0].Subnet.Id
    $bep = Get-AzLoadBalancerBackendAddressPoolConfig -Name $ELDBackEndPoolName -LoadBalancer $slb
    $NI.IpConfigurations[0].LoadBalancerBackendAddressPools = $bep
    $NI | Set-AzNetworkInterface
}

# Step 6: Assign the outbound SNAT rules
$myelb = Get-AzLoadBalancer -Name $slb.Name
$myelb | Add-AzLoadBalancerOutboundRuleConfig -Name $ELBOutboundRulename -FrontendIpConfiguration $frontend -BackendAddressPool $backendAddressPool -Protocol "All"

# Step 7: Configure the loadbalancer
$myelb | Set-AzLoadBalancer

#endregion
