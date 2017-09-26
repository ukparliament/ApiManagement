<#
.SYNOPSIS
Deletes all existing APIs.

.DESCRIPTION
Deletes all existing APIs.

.PARAMETER APIResourceGroupName
Name of the Resource Group where the API Management is.

.PARAMETER APIManagementName
Name of the API Management.

.NOTES
This script is for use as a part of deployment in VSTS only.
#>

Param(
    [Parameter(Mandatory=$true)] [string] $APIResourceGroupName,
    [Parameter(Mandatory=$true)] [string] $APIManagementName
)
$ErrorActionPreference = "Stop"

function Log([Parameter(Mandatory=$true)][string]$LogText){
    Write-Host ("{0} - {1}" -f (Get-Date -Format "HH:mm:ss.fff"), $LogText)
}

Log "Get API Management context"
$management=New-AzureRmApiManagementContext -ResourceGroupName $APIResourceGroupName -ServiceName $APIManagementName

Log "Remove examples"

Log "Remove subscriptions to API Products"
Get-AzureRmApiManagementSubscription -Context $management | Remove-AzureRmApiManagementSubscription -Context $management
Log "Remove API Products"
Get-AzureRmApiManagementProduct -Context $management | Remove-AzureRmApiManagementProduct -Context $management
Log "Remove endpoints"
Get-AzureRmApiManagementApi -Context $management | Select-Object ApiId -ExpandProperty ApiId | Remove-AzureRmApiManagementApi -Context $management

Log "Job well done!"