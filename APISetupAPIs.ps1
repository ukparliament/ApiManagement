<#
.SYNOPSIS
Generates API.

.DESCRIPTION
Creates list of APIs.

.PARAMETER APIResourceGroupName
Name of the Resource Group where the API Management is.

.PARAMETER APIManagementName
Name of the API Management.

.NOTES
This script is for use as a part of deployment in VSTS only.
#>

Param(
    [Parameter(Mandatory=$true)] [string] $APIResourceGroupName,
    [Parameter(Mandatory=$true)] [string] $OrchestrationResourceGroupName,
    [Parameter(Mandatory=$true)] [string] $AzureFunctionsName,
    [Parameter(Mandatory=$true)] [string] $FixedQueryName,
	[Parameter(Mandatory=$true)] [string] $PhotoAPIName,
    [Parameter(Mandatory=$true)] [string] $SearchAPIName,
    [Parameter(Mandatory=$true)] [string] $APIManagementName,
	[Parameter(Mandatory=$true)] [string] $JMXUserName,
    [Parameter(Mandatory=$true)] [string] $MasterJolokiaSecret0,
    [Parameter(Mandatory=$true)] [string] $MasterJolokiaSecret1,
    [Parameter(Mandatory=$true)] [int] $GraphDBsubnetIP3rdGroup,
    [Parameter(Mandatory=$true)] [string] $PoliciesFolderLocation,
	[Parameter(Mandatory=$true)][AllowEmptyString()] [string] $APIPrefix
)
$ErrorActionPreference = "Stop"
$graphDBsubnetIP2ndGroups=$(0,128)

function Log([Parameter(Mandatory=$true)][string]$LogText){
    Write-Host ("{0} - {1}" -f (Get-Date -Format "HH:mm:ss.fff"), $LogText)
}

Log "Getting master key from Azure Functions"
$funcProperties=Invoke-AzureRmResourceAction -ResourceGroupName $OrchestrationResourceGroupName -ResourceType Microsoft.Web/sites/config -ResourceName "$AzureFunctionsName/publishingcredentials" -Action list -ApiVersion 2015-08-01 -Force
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $funcProperties.properties.publishingUserName,$funcProperties.properties.publishingPassword)))
$masterKeyResponse=Invoke-RestMethod -Uri "https://$AzureFunctionsName.scm.azurewebsites.net/api/functions/admin/masterkey" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)} -Method GET

Log "Retrieving IdGenerator's key"
$functionKeyResponse=Invoke-RestMethod -Uri "https://$AzureFunctionsName.azurewebsites.net/admin/functions/IdGenerator/keys?code=$($masterKeyResponse.masterKey)" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)} -Method GET
$idGeneratorUrl="https://$AzureFunctionsName.azurewebsites.net/api/IdGenerator?code=$($functionKeyResponse.keys[0].value)"

Log "Get API Management context"
$management=New-AzureRmApiManagementContext -ResourceGroupName $APIResourceGroupName -ServiceName $APIManagementName

Log "Create APIs"

Log "Fixed Query"
$serviceUrl="https://$FixedQueryName.azurewebsites.net/"
$apiFixedQuery=Get-AzureRmApiManagementApi -Context $management | where ServiceUrl -EQ $serviceUrl
if ($apiFixedQuery -eq $null) {
	$path="fixed-query"
	$existingApi=Get-AzureRmApiManagementApi -Context $management | where Path -EQ $path
	if ($existingApi -ne $null) {
		$path="$APIPrefix/$path"
	}
	$apiFixedQuery=New-AzureRmApiManagementApi -Context $management -Name "$($APIPrefix)Fixed Query" -ServiceUrl $serviceUrl -Protocols @("https") -Path "/$path"
	$operationFixedQuery=New-AzureRmApiManagementOperation -Context $management -ApiId $apiFixedQuery.ApiId -Name "Get" -Method "GET" -UrlTemplate "/*"
	Set-AzureRmApiManagementPolicy -Context $management -ApiId $apiFixedQuery.ApiId -OperationId $operationFixedQuery.OperationId -PolicyFilePath "$PoliciesFolderLocation\FixedQueryGET.xml"
}

Log "Photo"
$serviceUrl="https://$PhotoAPIName.azurewebsites.net/"
$apiPhoto=Get-AzureRmApiManagementApi -Context $management | where ServiceUrl -EQ $serviceUrl
if ($apiPhoto -eq $null) {
	$path="photo"
	$existingApi=Get-AzureRmApiManagementApi -Context $management | where Path -EQ $path
	if ($existingApi -ne $null) {
		$path="$APIPrefix/$path"
	}
	$apiPhoto=New-AzureRmApiManagementApi -Context $management -Name "$($APIPrefix)Photo" -ServiceUrl $serviceUrl -Protocols @("https") -Path "/$path"
	$operationPhoto=New-AzureRmApiManagementOperation -Context $management -ApiId $apiPhoto.ApiId -Name "Get" -Method "GET" -UrlTemplate "/*"
	Set-AzureRmApiManagementPolicy -Context $management -ApiId $apiPhoto.ApiId -OperationId $operationPhoto.OperationId -PolicyFilePath "$PoliciesFolderLocation\PhotoGET.xml"
}

Log "Search"
$serviceUrl="https://$SearchAPIName.azurewebsites.net/"
$apiSearch=Get-AzureRmApiManagementApi -Context $management | where ServiceUrl -EQ $serviceUrl
if ($apiSearch -eq $null) {
	$path="search"
	$existingApi=Get-AzureRmApiManagementApi -Context $management | where Path -EQ $path
	if ($existingApi -ne $null) {
		$path="$APIPrefix/$path"
	}
	$apiSearch=New-AzureRmApiManagementApi -Context $management -Name "$($APIPrefix)Search" -ServiceUrl $serviceUrl -Protocols @("https") -Path "/$path"
	$operationSearch1=New-AzureRmApiManagementOperation -Context $management -ApiId $apiSearch.ApiId -Name "Description" -Method "GET" -UrlTemplate "/description"
	$searchDescriptionGETPolicy=Get-Content -Path "$PoliciesFolderLocation\SearchDescriptionGET.xml" -Raw
	Set-AzureRmApiManagementPolicy -Context $management -ApiId $apiSearch.ApiId -OperationId $operationSearch1.OperationId -Policy ($searchDescriptionGETPolicy -f $SearchAPIName, $apiManagementName)
	$requestSearchGET=New-Object -TypeName Microsoft.Azure.Commands.ApiManagement.ServiceManagement.Models.PsApiManagementRequest -Property @{
		QueryParameters=@(
			New-Object -TypeName Microsoft.Azure.Commands.ApiManagement.ServiceManagement.Models.PsApiManagementParameter -Property @{
				Name="q"
				Type="string"
				Required=$true
			}
			New-Object -TypeName Microsoft.Azure.Commands.ApiManagement.ServiceManagement.Models.PsApiManagementParameter -Property @{
				Name="start"
				Type="number"
				Required=$false
			}
			New-Object -TypeName Microsoft.Azure.Commands.ApiManagement.ServiceManagement.Models.PsApiManagementParameter -Property @{
				Name="pagesize"
				Type="number"
				Required=$false
			}
		)
	}
	$operationSearch2=New-AzureRmApiManagementOperation -Context $management -ApiId $apiSearch.ApiId -Name "Search" -Method "GET" -UrlTemplate "/" -Request $requestSearchGET
	Set-AzureRmApiManagementPolicy -Context $management -ApiId $apiSearch.ApiId -OperationId $operationSearch2.OperationId -PolicyFilePath "$PoliciesFolderLocation\SearchGET.xml"
}

$apiSPARQL=@()
for($i=0;$i -lt 2;$i++) {
    Log "Read-only SPARQL Endpoint Master $i"
	$serviceUrl="http://10.$($graphDBsubnetIP2ndGroups[$i]).$GraphDBsubnetIP3rdGroup.30/repositories/Master"
	$apiSPARQLN=Get-AzureRmApiManagementApi -Context $management | where ServiceUrl -EQ $serviceUrl
	if ($apiSPARQLN -eq $null) {
		$path="sparql-endpoint/master-$i"
		$existingApi=Get-AzureRmApiManagementApi -Context $management | where Path -EQ $path
		if ($existingApi -ne $null) {
			$path="$APIPrefix/$path"
		}
		$apiSPARQLN=New-AzureRmApiManagementApi -Context $management -Name "$($APIPrefix)Read-only SPARQL Endpoint $i" -ServiceUrl $serviceUrl -Protocols @("https") -Path "/$path"
		New-AzureRmApiManagementOperation -Context $management -ApiId $apiSPARQLN.ApiId -Name "Get" -Method "GET" -UrlTemplate "/*"
		$operationSPARQL=New-AzureRmApiManagementOperation -Context $management -ApiId $apiSPARQLN.ApiId -Name "Post" -Method "POST" -UrlTemplate "/"
		Set-AzureRmApiManagementPolicy -Context $management -ApiId $apiSPARQLN.ApiId -OperationId $operationSPARQL.OperationId -PolicyFilePath "$PoliciesFolderLocation\SPARQLEndpointPOST.xml"
	}
    $apiSPARQL+=$apiSPARQLN
}

Log "Graph Store"
$serviceUrl="http://10.$($graphDBsubnetIP2ndGroups[0]).$GraphDBsubnetIP3rdGroup.30/"
$apiGraphStore=Get-AzureRmApiManagementApi -Context $management | where where {($_.ServiceUrl -EQ $serviceUrl) -and ($_.Name -match "Store")}
if ($apiGraphStore -eq $null) {
	$path="graph-store"
	$existingApi=Get-AzureRmApiManagementApi -Context $management | where Path -EQ $path
	if ($existingApi -ne $null) {
		$path="$APIPrefix/$path"
	}
	$apiGraphStore=New-AzureRmApiManagementApi -Context $management -Name "$($APIPrefix)Graph Store" -ServiceUrl $serviceUrl -Protocols @("https") -Path "/$path"
	New-AzureRmApiManagementOperation -Context $management -ApiId $apiGraphStore.ApiId -Name "Get" -Method "GET" -UrlTemplate "/*"
	New-AzureRmApiManagementOperation -Context $management -ApiId $apiGraphStore.ApiId -Name "Post" -Method "POST" -UrlTemplate "/*"
	New-AzureRmApiManagementOperation -Context $management -ApiId $apiGraphStore.ApiId -Name "Delete" -Method "DELETE" -UrlTemplate "/*"
	New-AzureRmApiManagementOperation -Context $management -ApiId $apiGraphStore.ApiId -Name "Put" -Method "PUT" -UrlTemplate "/*"
}

Log "API Health"
$serviceUrl="https://$APIManagementName.portal.azure-api.net"
$apiHealth=Get-AzureRmApiManagementApi -Context $management | where ServiceUrl -EQ $serviceUrl
if ($apiHealth -eq $null) {
	apiHealth=New-AzureRmApiManagementApi -Context $management -Name "API Health" -ServiceUrl $serviceUrl -Protocols @("https") -Path "/api-health"
	$operationAPIHealth=New-AzureRmApiManagementOperation -Context $management -ApiId $apiHealth.ApiId -Name "Get" -Method "GET" -UrlTemplate "/*"
	Set-AzureRmApiManagementPolicy -Context $management -ApiId $apiHealth.ApiId -OperationId $operationAPIHealth.OperationId -PolicyFilePath "$PoliciesFolderLocation\APIHealthGET.xml"
}

Log "Id Generator"
$apiIdGenerate=Get-AzureRmApiManagementApi -Context $management | where ServiceUrl -EQ $idGeneratorUrl
if ($apiIdGenerate -eq $null) {
	$path="id/generate"
	$existingApi=Get-AzureRmApiManagementApi -Context $management | where Path -EQ $path
	if ($existingApi -ne $null) {
		$path="$APIPrefix/$path"
	}
	$apiIdGenerate=New-AzureRmApiManagementApi -Context $management -Name "$($APIPrefix)Id Generator" -ServiceUrl $idGeneratorUrl -Protocols @("https") -Path "/$path"
	$operationIdGenerate=New-AzureRmApiManagementOperation -Context $management -ApiId $apiIdGenerate.ApiId -Name "Get" -Method "GET" -UrlTemplate "/"
	Set-AzureRmApiManagementPolicy -Context $management -ApiId $apiIdGenerate.ApiId -OperationId $operationIdGenerate.OperationId -PolicyFilePath "$PoliciesFolderLocation\IdGenerateGET.xml"
}

$apiJMX=@()
$requestJMXN=New-Object -TypeName Microsoft.Azure.Commands.ApiManagement.ServiceManagement.Models.PsApiManagementRequest -Property @{
    Headers=@(
        New-Object -TypeName Microsoft.Azure.Commands.ApiManagement.ServiceManagement.Models.PsApiManagementParameter -Property @{
            Name="Content-Type";
            Values="application/json";
            Type="string";
            Required=$true;
        }
    )
}
$jmxPOSTPolicy=Get-Content -Path "$PoliciesFolderLocation\JavaManagementPOST.xml" -Raw
$jolokias=@($MasterJolokiaSecret0,$MasterJolokiaSecret1)
for($i=0;$i -lt 2;$i++) {
    Log "Java Management GraphDB Master $i"
	$serviceUrl="http://10.$($graphDBsubnetIP2ndGroups[$i]).$GraphDBsubnetIP3rdGroup.30/jolokia"
	$apiJMXN=Get-AzureRmApiManagementApi -Context $management | where ServiceUrl -EQ $serviceUrl
	if ($apiJMXN -eq $null) {
		$path="jolokia/master-$i"
		$existingApi=Get-AzureRmApiManagementApi -Context $management | where Path -EQ $path
		if ($existingApi -ne $null) {
			$path="$APIPrefix/$path"
		}
		$apiJMXN=New-AzureRmApiManagementApi -Context $management -Name "$($APIPrefix)Java Management GraphDB Master $i" -ServiceUrl $serviceUrl -Protocols @("https") -Path "/$path"
		$operationJMXN=New-AzureRmApiManagementOperation -Context $management -ApiId $apiJMXN.ApiId -Name "Post" -Method "POST" -UrlTemplate "/" -Request $requestJMXN
		Set-AzureRmApiManagementPolicy -Context $management -ApiId $apiJMXN.ApiId -OperationId $operationJMXN.OperationId -Policy ($jmxPOSTPolicy -f $JMXUserName, $jolokias[$i])
	}
    $apiJMX+=$apiJMXN
}

$apiRDF4J=@()
for($i=0;$i -lt 2;$i++) {
    Log "RDF4J Master $i"
	$serviceUrl="http://10.$($graphDBsubnetIP2ndGroups[$i]).$GraphDBsubnetIP3rdGroup.30/"
	$apiRDF4JN=Get-AzureRmApiManagementApi -Context $management | where {($_.ServiceUrl -EQ $serviceUrl) -and ($_.Name -match "RDF4J")}
	if ($apiRDF4JN -eq $null) {
		$path="rdf4j/master-$i"
		$existingApi=Get-AzureRmApiManagementApi -Context $management | where Path -EQ $path
		if ($existingApi -ne $null) {
			$path="$APIPrefix/$path"
		}
		$apiRDF4JN=New-AzureRmApiManagementApi -Context $management -Name "$($APIPrefix)RDF4J Master $i" -ServiceUrl $serviceUrl -Protocols @("https") -Path "/$path"
		New-AzureRmApiManagementOperation -Context $management -ApiId $apiRDF4JN.ApiId -Name "Get" -Method "GET" -UrlTemplate "/*"
		New-AzureRmApiManagementOperation -Context $management -ApiId $apiRDF4JN.ApiId -Name "Post" -Method "POST" -UrlTemplate "/*"
	}
    $apiRDF4J+=$apiRDF4JN
}

Log "Job well done!"