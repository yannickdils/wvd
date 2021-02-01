#FSLogix Issue : 0x00000020 : The process cannot access the file because it is being used by another process

The script is provided as-is, the following parameters are required in order to run the script.

* Mode: you can alert of react to a possible lingered fslogix profile (under construction)
* ProfileStorageAccount: you need to provide the storage account name where you store your FSLogix containers
* ProfileShare: following your storage account, we also need the specific file share
* StorageAccountResourceGroupName: our resource group name where our storage account is located is required

Note: The script is currently "designed" to query only one storage account/file share, and only one host pool per run. You could of course alter this to check all host pools and related storage accounts.
The script loops through your active Windows Virtual Desktop sessions and active storage handles.
It then checks each storage handle, whether or not it has a corresponding active WVD session. If not you are presented with the virtual machine name where the FSLogix container is mounted.