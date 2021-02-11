### How to enable SNAT (Source Network Address Translation) on your Windows Virtual Desktop hosts



The script is provided as-is, alter the input variables to your needs

What is SNAT? In our use case, we want to use SNAT to masquerade our back-end WVD Host IP Addresses to a single Public IP address.
What is required? We need a Standard Public Azure Loadbalancer configured on top of our WVD hosts and a SNAT rule configured to allow outbound connections.

Change the following input variables before running the script.

* $ELBPurpose = "enter the purpose of your loadbalancer (ex. wvd)"
* $ELBlocation = "enter the location of your loadbalancer (ex. westeurope)"
* $SKU = "enter the SKU of your loadbalancer (ex. standard)"
* $ELBResourceGroup =  "enter the resource group name of your loadbalancer (ex. prd-network-rg)"

Change the following naming conventions to meet your needs.

* $ELBconvention = "-elb"
* $PIPconvention = "-pip"
* $FrontEndConvention = "-fep"
* $BackEndConvention = "-bep"
* $OutboundRuleConvention = "-obr"

* $ELBname = $ELBPurpose + $ELBconvention
* $ELBpip = $ELBname + $PIPconvention
* $ELBFrontEndName = $ELBname + $FrontEndConvention
* $ELDBackEndPoolName = $ELBname + $BackEndConvention
* $ELBOutboundRulename = $ELBname + $OutboundRuleConvention