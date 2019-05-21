<#
.SYNOPSIS
Deletes all APIs for a particular relase.

.DESCRIPTION
Deletes all APIs for a particular relase.

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
    [Parameter(Mandatory=$true)] [string] $APIPrefix,
    [Parameter(Mandatory=$true)] [string] $GenericName
)
$ErrorActionPreference = "Stop"

function Log([Parameter(Mandatory=$true)][string]$LogText){
    Write-Host ("{0} - {1}" -f (Get-Date -Format "HH:mm:ss.fff"), $LogText)
}

Log "Get API Management context"
$management=New-AzureRmApiManagementContext -ResourceGroupName $APIResourceGroupName -ServiceName $APIManagementName

Log "Remove $APIPrefix"

Log "Remove Products"
$products=Get-AzureRmApiManagementProduct -Context $management | Where-Object Title -Match "$APIPrefix -" 
foreach ($product in $products){
    Log $product.Title
    $subscription=Get-AzureRmApiManagementSubscription -Context $management -ProductId $product.ProductId
    Remove-AzureRmApiManagementSubscription -Context $management -SubscriptionId $subscription.SubscriptionId
    Remove-AzureRmApiManagementProduct -Context $management -ProductId $product.ProductId
}

Log "Remove APIs"
$apis=Get-AzureRmApiManagementApi -Context $management | Where-Object Name -Match "$APIPrefix -" 
foreach ($api in $apis){
    Log $api.Name
    Remove-AzureRmApiManagementApi -Context $management -ApiId $api.ApiId
}

Log "Remove Named Values"
$properties=Get-AzureRmApiManagementProperty -Context $management | Where-Object Name -Match "$APIPrefix-" 
foreach ($property in $properties){
    Log $property.Name
    Remove-AzureRmApiManagementProperty -Context $management -PropertyId $property.PropertyId
}

$appNames=@("fixedquery","search","photo")

Log "Remove web apps"
foreach ($name in $appNames) {
    Log "$name"
    Remove-AzureRmWebApp -ResourceGroupName "$APIResourceGroupName" -Name "$name$GenericName" -Force
}

Log "Remove app service"
Remove-AzureRmAppServicePlan -ResourceGroupName "$APIResourceGroupName" -Name "apps$GenericName" -Force

Log "Job well done!"