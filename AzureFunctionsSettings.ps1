<#
.SYNOPSIS
Generates API.

.DESCRIPTION
Creates endpoints to access GraphDB.

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
    [Parameter(Mandatory=$true)] [string] $AzureFunctionsResourceGroupName,
    [Parameter(Mandatory=$true)] [string] $AzureFunctionsName
    
)

$ErrorActionPreference = "Stop"

function Log([Parameter(Mandatory=$true)][string]$LogText){
    Write-Host ("{0} - {1}" -f (Get-Date -Format "HH:mm:ss.fff"), $LogText)
}

Log "Get API Management context"
$management=New-AzureRmApiManagementContext -ResourceGroupName $APIResourceGroupName -ServiceName $APIManagementName
Log "Retrives subscription"
$apiProductOrchestration=Get-AzureRmApiManagementProduct -Context $management -Title "Parliament - Orchestration"
$subscription=Get-AzureRmApiManagementSubscription -Context $management -ProductId $apiProductOrchestration.ProductId
$subscriptionKey=$subscription.PrimaryKey

Log "Gets current settings"
$webApp = Get-AzureRmwebApp -ResourceGroupName $AzureFunctionsResourceGroupName -Name $AzureFunctionsName
$webAppSettings = $webApp.SiteConfig.AppSettings
$settings=@{}
foreach($set in $webAppSettings){ 
    $settings[$set.Name]=$set.Value
}

Log "Sets new subscription key"
$settings["SubscriptionKey"]=$subscriptionKey
Set-AzureRmWebApp -ResourceGroupName $AzureFunctionsResourceGroupName -Name $AzureFunctionsName -AppSettings $settings

Log "Job well done!"