#region requirements

# The Az.ResourceMover powershell module needs to be installed
# Install-Module Az.ResourceMover

#endregion

#region variables

$MoveCollectionName = "MyFirstMove"
$IdentityType = "SystemAssigned"

$SourceSubscriptionID = Get-AzSubscription | Out-GridView -Title "Please select your source subscription" -PassThru
$TargetSubscriptionID = Get-AzSubscription | Out-GridView -Title "Please select your target subscription" -PassThru

# Set Source AZ Context
Set-AzContext -Subscription $SourceSubscriptionID

$SourceResourceGroup = Get-AzResourceGroup | Out-GridView -Title "Please select the resource groups you want to move to a new subscription" -OutputMode Multiple

$SourceResourceGroup_Name = $SourceResourceGroup.ResourceGroupName
$TargetResourceGroup_Name = $SourceResourceGroup_Name
$TargetResourceGroup_Location = $SourceResourceGroup.Location
$TargetResourceGroup_Object = "mc-" + $TargetResourceGroup_Name

#endregion

#region create move collection

# Set Target AZ Context
Set-AzContext -Subscription $TargetSubscriptionID

# Create Target Resource Group
$MoveCollectionResourceGroup = New-AzResourceGroup -Name $TargetResourceGroup_Name -Location $TargetResourceGroup_Location

# Register Resource Provider
Register-AzResourceProvider -ProviderNamespace Microsoft.Migrate

While (((Get-AzResourceProvider -ProviderNamespace Microsoft.Migrate) | where { $_.RegistrationState -eq "Registered" -and $_.ResourceTypes.ResourceTypeName -eq "moveCollections" } | measure).Count -eq 0) {
    Start-Sleep -Seconds 5
    Write-Output "Waiting for registration to complete."
}
Write-Output "Registration Complete"

# Create a MoveCollection object
$MoveCollection = New-AzResourceMoverMoveCollection -Name $TargetResourceGroup_Object `
    -ResourceGroupName $TargetResourceGroup_Name `
    -SourceRegion $SourceResourceGroup.Location `
    -TargetRegion $TargetResourceGroup_Location `
    -Location "NorthEurope" `
    -IdentityType $IdentityType

# Grant access to the managed identity
$identityPrincipalId = $moveCollection.IdentityPrincipalId

New-AzRoleAssignment -ObjectId $identityPrincipalId -RoleDefinitionName Contributor -Scope "/subscriptions/$TargetSubscriptionID"

New-AzRoleAssignment -ObjectId $identityPrincipalId -RoleDefinitionName "User Access Administrator" -Scope "/subscriptions/$TargetSubscriptionID"


#endregion

#Is it really that easy?

$SourceResource = Get-AzResource | Out-GridView -Title "Please select the resources you want to move" -OutputMode Multiple
Move-AzResource -DestinationResourceGroupName $SourceResource.ResourceGroupName -DestinationSubscriptionId $TargetSubscriptionID.Id -ResourceId $SourceResource.Id

#


