<#
.SYNOPSIS
Generates API for robots.txt request.

.DESCRIPTION
Generates API for robots.txt request.

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

Log "Create robots.txt"
$serviceUrl=""
$apiRobots=Get-AzureRmApiManagementApi -Context $management | where ServiceUrl -EQ $serviceUrl
if ($apiRobots -eq $null) {
    $apiRobots=New-AzureRmApiManagementApi -Context $management -Name "robots.txt" -ServiceUrl $serviceUrl -Protocols @("http","https") -Path "/robots.txt"
    $operationAPIRobots=New-AzureRmApiManagementOperation -Context $management -ApiId $apiRobots.ApiId -Name "Get" -Method "GET" -UrlTemplate "/"
    Set-AzureRmApiManagementPolicy -Context $management -ApiId $apiRobots.ApiId -OperationId $operationAPIRobots.OperationId -PolicyFilePath "$PoliciesFolderLocation\APIRobotsGET.xml"
}

Log "Create API product"
$apiProduct=New-AzureRmApiManagementProduct -Context $management -Title "API Management - Public [robots.txt]" -Description "For parliamentary use only." -ApprovalRequired $false -SubscriptionRequired $false
Add-AzureRmApiManagementApiToProduct -Context $management -ProductId $apiProduct.ProductId -ApiId $apiRobots.ApiId

Log "Job well done!"