<#
.SYNOPSIS
Generates API to check availability of the API Management.

.DESCRIPTION
Generates API to check availability of the API Management.

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

Log "Create API Health"
$serviceUrl="https://$APIManagementName.portal.azure-api.net"
$apiHealth=Get-AzureRmApiManagementApi -Context $management | where ServiceUrl -EQ $serviceUrl
if ($apiHealth -eq $null) {
    $apiHealth=New-AzureRmApiManagementApi -Context $management -Name "API Health" -ServiceUrl $serviceUrl -Protocols @("https") -Path "/api-health"
    $operationAPIHealth=New-AzureRmApiManagementOperation -Context $management -ApiId $apiHealth.ApiId -Name "Get" -Method "GET" -UrlTemplate "/*"
    Set-AzureRmApiManagementPolicy -Context $management -ApiId $apiHealth.ApiId -OperationId $operationAPIHealth.OperationId -PolicyFilePath "$PoliciesFolderLocation\APIHealthGET.xml"
}

Log "Create API product"
$apiProduct=New-AzureRmApiManagementProduct -Context $management -Title "API Management - Parliament [Availability]" -Description "For parliamentary use only." -ApprovalRequired $true -SubscriptionsLimit 1 -SubscriptionRequired $true
Add-AzureRmApiManagementApiToProduct -Context $management -ProductId $apiProduct.ProductId -ApiId $apiHealth.ApiId

Log "Job well done!"