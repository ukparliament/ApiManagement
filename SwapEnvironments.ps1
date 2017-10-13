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
	[Parameter(Mandatory=$true)] [string] $APIPrefix1,
	[Parameter(Mandatory=$true)] [string] $APIPrefix2
)
$ErrorActionPreference = "Stop"

$genericNameAPINames=@("Fixed Query","Id Generator","Photo","Search")
$ip3rdGroupAPINames=@("Graph Store","Java Management GraphDB Master","RDF4J Master","Read-only SPARQL Endpoint")
$namedValuesNames=@("IdGeneratorKey","JMXUserName","MasterJolokiaSecret","WorkbenchAuthorization")

function Log([Parameter(Mandatory=$true)][string]$LogText){
    Write-Host ("{0} - {1}" -f (Get-Date -Format "HH:mm:ss.fff"), $LogText)
}

Log "Get API Management context"
$management=New-AzureRmApiManagementContext -ResourceGroupName $APIResourceGroupName -ServiceName $APIManagementName

Log "Retrieve generic names"
$apiFixedQuery1=Get-AzureRmApiManagementApi -Context $management | Where-Object Name -EQ "$APIPrefix1 - Fixed Query"
$genericName1=$apiFixedQuery1.ServiceUrl.Substring(18,$apiFixedQuery1.ServiceUrl.IndexOf('.')-18)
$genericName2=Get-AzureRmApiManagementApi -Context $management | Where-Object Name -EQ "$APIPrefix2 - Fixed Query"
$genericName2=$apiFixedQuery2.ServiceUrl.Substring(18,$apiFixedQuery2.ServiceUrl.IndexOf('.')-18)

Log "Retrieve IP's 3rd groups"
$apiGraphStore1=Get-AzureRmApiManagementApi -Context $management | Where-Object Name -EQ "$APIPrefix1 - Graph Store"
$graphDBsubnetIP3rdGroup1=$apiGraphStore1.ServiceUrl.Split('.')[2]
$apiGraphStore2=Get-AzureRmApiManagementApi -Context $management | Where-Object Name -EQ "$APIPrefix2 - Graph Store"
$graphDBsubnetIP3rdGroup2=$apiGraphStore2.ServiceUrl.Split('.')[2]

Log "Swap $APIPrefix1 with $APIPrefix2"

Log "API Management"
foreach ($name in $genericNameAPINames){
	$api=Get-AzureRmApiManagementApi -Context $management -Name "$APIPrefix1 - $name" 
	Log $api.Name	
	Set-AzureRmApiManagementApi -Context $management -ApiId $api.ApiId -Name $api.Name -Protocols $api.Protocols -ServiceUrl $api.ServiceUrl.Replace($genericName1, $genericName2)
	$api=Get-AzureRmApiManagementApi -Context $management -Name "$APIPrefix2 - $name" 
	Log $api.Name	
	Set-AzureRmApiManagementApi -Context $management -ApiId $api.ApiId -Name $api.Name -Protocols $api.Protocols -ServiceUrl $api.ServiceUrl.Replace($genericName2, $genericName1)
}
foreach ($name in $ip3rdGroupAPINames){
	$api=Get-AzureRmApiManagementApi -Context $management -Name "$APIPrefix1 - $name" 
	Log $api.Name	
	Set-AzureRmApiManagementApi -Context $management -ApiId $api.ApiId -Name $api.Name -Protocols $api.Protocols -ServiceUrl $api.ServiceUrl.Replace(".$apiGraphStore1.30/", ".$apiGraphStore2.30/")
	$api=Get-AzureRmApiManagementApi -Context $management -Name "$APIPrefix2 - $name" 
	Log $api.Name	
	Set-AzureRmApiManagementApi -Context $management -ApiId $api.ApiId -Name $api.Name -Protocols $api.Protocols -ServiceUrl $api.ServiceUrl.Replace(".$apiGraphStore2.30/", ".$apiGraphStore1.30/")
}
foreach ($name in $namedValuesNames){
	Log "Named value $name"
	$namedValue1=Get-AzureRmApiManagementProperty -Context $management -Name "$APIPrefix1-$name"
	$namedValue2=Get-AzureRmApiManagementProperty -Context $management -Name "$APIPrefix2-$name"
	Log "Swap $($namedValue2.Value) with $($namedValue2.Value)"
	Set-AzureRmApiManagementProperty -Context $management -PropertyId $namedValue1.PropertyId -Value $namedValue2.Value -Secret $true
	Set-AzureRmApiManagementProperty -Context $management -PropertyId $namedValue2.PropertyId -Value $namedValue1.Value -Secret $true
}

Log "Logic App"
$logicApp1=Get-AzureRmLogicApp -ResourceGroupName "data-orchestration$genericName1" -Name "getlist-epetition"
$logicApp2=Get-AzureRmLogicApp -ResourceGroupName "data-orchestration$genericName2" -Name "getlist-epetition"
$v1=$logicApp1.Definition.Property("actions").Property("GetMaxUpdatedAt").Property("inputs").Property("uri").Value
$v2=$logicApp2.Definition.Property("actions").Property("GetMaxUpdatedAt").Property("inputs").Property("uri").Value
Log "Swap $v1 with $v2"
$logicApp1.Definition.Property("actions").Property("GetMaxUpdatedAt").Property("inputs").Property("uri").Value=$v2
$logicApp2.Definition.Property("actions").Property("GetMaxUpdatedAt").Property("inputs").Property("uri").Value=$v1
$v1=$logicApp1.Definition.Property("actions").Property("GetMaxUpdatedAt").Property("inputs").Property("headers").Property("Ocp-Apim-Subscription-Key").Value.Value
$v2=$logicApp2.Definition.Property("actions").Property("GetMaxUpdatedAt").Property("inputs").Property("headers").Property("Ocp-Apim-Subscription-Key").Value.Value
Log "Swap $v1 with $v2"
$logicApp1.Definition.Property("actions").Property("GetMaxUpdatedAt").Property("inputs").Property("headers").Property("Ocp-Apim-Subscription-Key").Value.Value=$v2
$logicApp2.Definition.Property("actions").Property("GetMaxUpdatedAt").Property("inputs").Property("headers").Property("Ocp-Apim-Subscription-Key").Value.Value=$v1
Set-AzureRmLogicApp -ResourceGroupName "data-orchestration$genericName1" -Name "getlist-epetition" -Definition $logicApp1.Definition -Force -Verbose
Set-AzureRmLogicApp -ResourceGroupName "data-orchestration$genericName2" -Name "getlist-epetition" -Definition $logicApp2.Definition -Force -Verbose

Log "Azure Functions"
$webApp1=Get-AzureRmWebApp -ResourceGroupName "data-orchestration$genericName1" -Name "func$genericName1"
$webApp2=Get-AzureRmWebApp -ResourceGroupName "data-orchestration$genericName2" -Name "func$genericName2"
$v1=$webApp1.SiteConfig.AppSettings["SubscriptionKey"]
$v2=$webApp2.SiteConfig.AppSettings["SubscriptionKey"]
Log "Swap $v1 with $v2"
$webApp1.SiteConfig.AppSettings["SubscriptionKey"]=$v2
$webApp2.SiteConfig.AppSettings["SubscriptionKey"]=$v1
$v1=$webApp1.SiteConfig.ConnectionStrings["Data"]
$v2=$webApp2.SiteConfig.ConnectionStrings["Data"]
Log "Swap $v1 with $v2"
$webApp1.SiteConfig.ConnectionStrings["Data"]=$v2
$webApp2.SiteConfig.ConnectionStrings["Data"]=$v1
Set-AzureRmWebApp -ResourceGroupName "data-orchestration$genericName1" -Name "func$genericName1" -AppSettings $webApp1.SiteConfig.AppSettings -ConnectionStrings $webApp1.SiteConfig.ConnectionStrings
Set-AzureRmWebApp -ResourceGroupName "data-orchestration$genericName2" -Name "func$genericName2" -AppSettings $webApp2.SiteConfig.AppSettings -ConnectionStrings $webApp2.SiteConfig.ConnectionStrings

Log "Web apps"
Log "Fixed query"
$webApp1=Get-AzureRmWebApp -ResourceGroupName "data-api" -Name "fixedquery$genericName1"
$webApp2=Get-AzureRmWebApp -ResourceGroupName "data-api" -Name "fixedquery$genericName2"
$v1=$webApp1.SiteConfig.AppSettings["SubscriptionKey"]
$v2=$webApp2.SiteConfig.AppSettings["SubscriptionKey"]
Log "Swap $v1 with $v2"
$webApp1.SiteConfig.AppSettings["SubscriptionKey"]=$v2
$webApp2.SiteConfig.AppSettings["SubscriptionKey"]=$v1
$v1=$webApp1.SiteConfig.AppSettings["SparqlEndpoint"]
$v2=$webApp2.SiteConfig.AppSettings["SparqlEndpoint"]
Log "Swap $v1 with $v2"
$webApp1.SiteConfig.AppSettings["SparqlEndpoint"]=$v2
$webApp2.SiteConfig.AppSettings["SparqlEndpoint"]=$v1
Set-AzureRmWebApp -ResourceGroupName "data-api" -Name "fixedquery$genericName1" -AppSettings $webApp1.SiteConfig.AppSettings
Set-AzureRmWebApp -ResourceGroupName "data-api" -Name "fixedquery$genericName2" -AppSettings $webApp2.SiteConfig.AppSettings
Log "Photo"
$webApp1=Get-AzureRmWebApp -ResourceGroupName "data-api" -Name "photo$genericName1"
$webApp2=Get-AzureRmWebApp -ResourceGroupName "data-api" -Name "photo$genericName2"
$v1=$webApp1.SiteConfig.ConnectionStrings["SparqlEndpoint"]
$v2=$webApp2.SiteConfig.ConnectionStrings["SparqlEndpoint"]
Log "Swap $v1 with $v2"
$webApp1.SiteConfig.ConnectionStrings["SparqlEndpoint"]=$v2
$webApp2.SiteConfig.ConnectionStrings["SparqlEndpoint"]=$v1
Set-AzureRmWebApp -ResourceGroupName "data-api" -Name "photo$genericName1" -ConnectionStrings $webApp1.SiteConfig.ConnectionStrings
Set-AzureRmWebApp -ResourceGroupName "data-api" -Name "photo$genericName2" -ConnectionStrings $webApp2.SiteConfig.ConnectionStrings
Log "Search"
$webApp1=Get-AzureRmWebApp -ResourceGroupName "data-api" -Name "search$genericName1"
$webApp2=Get-AzureRmWebApp -ResourceGroupName "data-api" -Name "search$genericName2"
$v1=$webApp1.SiteConfig.AppSettings["ApiManagementServiceUrl"]
$v2=$webApp2.SiteConfig.AppSettings["ApiManagementServiceUrl"]
Log "Swap $v1 with $v2"
$webApp1.SiteConfig.AppSettings["ApiManagementServiceUrl"]=$v2
$webApp2.SiteConfig.AppSettings["ApiManagementServiceUrl"]=$v1
Set-AzureRmWebApp -ResourceGroupName "data-api" -Name "search$genericName1" -ConnectionStrings $webApp1.SiteConfig.ConnectionStrings
Set-AzureRmWebApp -ResourceGroupName "data-api" -Name "search$genericName2" -ConnectionStrings $webApp2.SiteConfig.ConnectionStrings

Log "Job well done!"