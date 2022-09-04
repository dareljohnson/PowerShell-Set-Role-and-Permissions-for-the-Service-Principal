# Set Role and Permissions for the Service Principal
# Author: Darel Johnson
# Created: 09/01/2022

# This script creates a Role assignment for the Service Principal for each Event Hub namespace that
# is configured with the ScaleDownTUs tag. Updates can be viewed in the Access control (IAM) secttion.
# Login-AzAccount

$appName = "EventHubScaler"  # The name of the Service Principal
$appRole = "Owner"           # Role
$tagValue = 1                # This must match the value you set for the tag name
$WhatIf = $true              # set to true to add role

$sp = Get-AzADServicePrincipal -DisplayName $appName
$applicationId = $sp.AppId
$subs = Get-AzSubscription
foreach($sub in $subs) {
    Set-AzContext $sub | Out-Null
    Write-Output "Context set to $($sub.Name)"

    $hubs = Get-AzEventHubNamespace
    foreach($hub in $hubs) {
        $hubName = $hub.Name
        $capacity = $hub.Sku.Capacity
        $autoInflate = $hub.IsAutoInflateEnabled
        $maxCapacity = $hub.MaximumThroughputUnits
		$hubTagValue = $hub.Tags['ScaleDownTUs']  

        $assignments = Get-AzRoleAssignment -Scope $hub.Id `
            -RoleDefinitionName $appRole `
            -ServicePrincipalName $applicationId
        
		if($hubTagValue -ne $null -and $hubTagValue -eq $tagValue)
		{
			if($null -eq $assignments) {
				$assignString = ""
			} else {
				$assignString = "[$appName ASSIGNED with tag:: $hubTagValue]"
			}
			
			if($autoInflate) {
				Write-Output "Namespace: $hubName :: TU: $capacity/$maxCapacity $scaleDownTUs $assignString"

				if($null -eq $assignments) {
					if($WhatIf -eq $false) {
						Write-Output "Adding $appRole role for $appName on $hubName [$hubTagValue]"
						New-AzRoleAssignment -Scope $hub.Id `
							-RoleDefinitionName $appRole `
							-ApplicationId $applicationId | Out-Null
					} else {
						Write-Output "[WHATIF] Adding $appRole role for $appName on $hubName [$hubTagValue]"
					}
				}
			} else {
				Write-Output "Namespace: $hubName :: TU: $capacity $assignString [$hubTagValue]"
			}
		}
        
    }
}

<#  Typical output from script above

	Context set to Developer Subscription Plan
	WARNING: Upcoming breaking changes in the cmdlet 'Get-AzEventHubNamespace' :

	- The output type 'Microsoft.Azure.Commands.EventHub.Models.PSNamespaceAttributes' is changing
	- The following properties in the output type are being deprecated : 'ResourceGroup'
	- The following properties are being added to the output type : 'ResourceGroupName' 'Tags'
	Note : Go to https://aka.ms/azps-changewarnings for steps to suppress this breaking change warning, and other information on breaking changes in Azure PowerShell.
	Namespace: app-evh1 :: TU: 1/40  [Scaler1 ASSIGNED]

#>