<#
.SYNOPSIS
Retrieves subscription key for availiability tests.

.DESCRIPTION
Retrieves subscription key for availiability tests.

.PARAMETER APIResourceGroupName
Name of the Resource Group where the API Management is.

.PARAMETER APIManagementName
Name of the API Management.

.NOTES
This script is for use as a part of deployment in VSTS only.
#>

Param(
    [Parameter(Mandatory=$true)] [string] $APIResourceGroupName,
    [Parameter(Mandatory=$true)] [string] $APIManagementName,	
	[Parameter(Mandatory=$true)][AllowEmptyString()] [string] $APIPrefix
)
$ErrorActionPreference = "Stop"
$graphDBsubnetIP2ndGroups=$(0,128)

function Log([Parameter(Mandatory=$true)][string]$LogText){
    Write-Host ("{0} - {1}" -f (Get-Date -Format "HH:mm:ss.fff"), $LogText)
}

Log "Get API Management context"
$management=New-AzureRmApiManagementContext -ResourceGroupName $APIResourceGroupName -ServiceName $APIManagementName

$apiProductAvailability=Get-AzureRmApiManagementProduct -Context $management -Title "$($APIPrefix)Parliament - Availability"

Log "Setting variables to use during deployment"
$subscriptionAvailability=Get-AzureRmApiManagementSubscription -Context $management -ProductId $apiProductAvailability.ProductId
Write-Host "##vso[task.setvariable variable=APISubscriptionAvailability]$($subscriptionAvailability.PrimaryKey)"

Log "Job well done!"