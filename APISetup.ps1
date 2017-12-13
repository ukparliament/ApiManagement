<#
.SYNOPSIS
Generates APIs.

.DESCRIPTION
Creates list of APIs and API products.

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
	[Parameter(Mandatory=$true)] [string] $ODataAPIName,
    [Parameter(Mandatory=$true)] [string] $SearchAPIName,
    [Parameter(Mandatory=$true)] [string] $APIManagementName,
	[Parameter(Mandatory=$true)] [string] $JMXUserName,
    [Parameter(Mandatory=$true)] [string] $MasterJolokiaSecret,
    [Parameter(Mandatory=$true)] [int] $GraphDBsubnetIP3rdGroup,
    [Parameter(Mandatory=$true)] [string] $PoliciesFolderLocation,
	[Parameter(Mandatory=$true)] [string] $APIPrefix
)
$ErrorActionPreference = "Stop"

function Log([Parameter(Mandatory=$true)][string]$LogText){
    Write-Host ("{0} - {1}" -f (Get-Date -Format "HH:mm:ss.fff"), $LogText)
}

Log "Get API Management context"
$management=New-AzureRmApiManagementContext -ResourceGroupName $APIResourceGroupName -ServiceName $APIManagementName

Log "Getting master key from Azure Functions"
$funcProperties=Invoke-AzureRmResourceAction -ResourceGroupName $OrchestrationResourceGroupName -ResourceType Microsoft.Web/sites/config -ResourceName "$AzureFunctionsName/publishingcredentials" -Action list -ApiVersion 2015-08-01 -Force
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $funcProperties.properties.publishingUserName,$funcProperties.properties.publishingPassword)))
$masterKeyResponse=Invoke-RestMethod -Uri "https://$AzureFunctionsName.scm.azurewebsites.net/api/functions/admin/masterkey" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)} -Method GET

Log "Retrieving IdGenerator's key"
$functionKeyResponse=Invoke-RestMethod -Uri "https://$AzureFunctionsName.azurewebsites.net/admin/functions/IdGenerator/keys?code=$($masterKeyResponse.masterKey)" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)} -Method GET
$idGeneratorUrl="https://$AzureFunctionsName.azurewebsites.net/api/IdGenerator"
New-AzureRmApiManagementProperty -Context $management -Name "$APIPrefix-IdGeneratorKey" -Value "$($functionKeyResponse.keys[0].value)" -Secret

Log "Create APIs"

Log "Fixed Query"
$serviceUrl="https://$FixedQueryName.azurewebsites.net/"
$apiFixedQuery=Get-AzureRmApiManagementApi -Context $management | where ServiceUrl -EQ $serviceUrl
if ($apiFixedQuery -eq $null) {
	$path="$APIPrefix/fixed-query"
	$apiFixedQuery=New-AzureRmApiManagementApi -Context $management -Name "$APIPrefix - Fixed Query" -ServiceUrl $serviceUrl -Protocols @("https") -Path "/$path"
	$operationFixedQuery=New-AzureRmApiManagementOperation -Context $management -ApiId $apiFixedQuery.ApiId -Name "Get" -Method "GET" -UrlTemplate "/*"
	Set-AzureRmApiManagementPolicy -Context $management -ApiId $apiFixedQuery.ApiId -OperationId $operationFixedQuery.OperationId -PolicyFilePath "$PoliciesFolderLocation\FixedQueryGET.xml"
}

Log "Photo"
$serviceUrl="https://$PhotoAPIName.azurewebsites.net/"
$apiPhoto=Get-AzureRmApiManagementApi -Context $management | where ServiceUrl -EQ $serviceUrl
if ($apiPhoto -eq $null) {
	$path="$APIPrefix/photo"
	$apiPhoto=New-AzureRmApiManagementApi -Context $management -Name "$APIPrefix - Photo" -ServiceUrl $serviceUrl -Protocols @("https") -Path "/$path"
	$operationPhoto=New-AzureRmApiManagementOperation -Context $management -ApiId $apiPhoto.ApiId -Name "Get" -Method "GET" -UrlTemplate "/*"
	Set-AzureRmApiManagementPolicy -Context $management -ApiId $apiPhoto.ApiId -OperationId $operationPhoto.OperationId -PolicyFilePath "$PoliciesFolderLocation\PhotoGET.xml"
}

Log "OData"
$serviceUrl="https://$ODataAPIName.azurewebsites.net/"
$apiOData=Get-AzureRmApiManagementApi -Context $management | where ServiceUrl -EQ $serviceUrl
if ($apiOData -eq $null) {
	$path="$APIPrefix/odata"
	$apiOData=New-AzureRmApiManagementApi -Context $management -Name "$APIPrefix - OData" -ServiceUrl $serviceUrl -Protocols @("https") -Path "/$path"
	$operationOData=New-AzureRmApiManagementOperation -Context $management -ApiId $apiOData.ApiId -Name "Get" -Method "GET" -UrlTemplate "/*"
	Set-AzureRmApiManagementPolicy -Context $management -ApiId $apiOData.ApiId -OperationId $operationOData.OperationId -PolicyFilePath "$PoliciesFolderLocation\ODataGET.xml"
}

Log "Search"
$serviceUrl="https://$SearchAPIName.azurewebsites.net/"
$apiSearch=Get-AzureRmApiManagementApi -Context $management | where ServiceUrl -EQ $serviceUrl
if ($apiSearch -eq $null) {
	$path="$APIPrefix/search"
	$apiSearch=New-AzureRmApiManagementApi -Context $management -Name "$APIPrefix - Search" -ServiceUrl $serviceUrl -Protocols @("https") -Path "/$path"
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

Log "Read-only SPARQL Endpoint Master"
$serviceUrl="http://10.0.$GraphDBsubnetIP3rdGroup.30/repositories/Master"
$apiSPARQL=Get-AzureRmApiManagementApi -Context $management | where ServiceUrl -EQ $serviceUrl
if ($apiSPARQL -eq $null) {
	$path="$APIPrefix/sparql-endpoint/master"
	$apiSPARQL=New-AzureRmApiManagementApi -Context $management -Name "$APIPrefix - Read-only SPARQL Endpoint" -ServiceUrl $serviceUrl -Protocols @("https") -Path "/$path"
	New-AzureRmApiManagementOperation -Context $management -ApiId $apiSPARQL.ApiId -Name "Get" -Method "GET" -UrlTemplate "/*"
	$operationSPARQL=New-AzureRmApiManagementOperation -Context $management -ApiId $apiSPARQL.ApiId -Name "Post" -Method "POST" -UrlTemplate "/"
	Set-AzureRmApiManagementPolicy -Context $management -ApiId $apiSPARQL.ApiId -OperationId $operationSPARQL.OperationId -PolicyFilePath "$PoliciesFolderLocation\SPARQLEndpointPOST.xml"
}
    
Log "Graph Store"
$serviceUrl="http://10.0.$GraphDBsubnetIP3rdGroup.30/"
$apiGraphStore=Get-AzureRmApiManagementApi -Context $management | where {($_.ServiceUrl -EQ $serviceUrl) -and ($_.Name -match "Store")}
if ($apiGraphStore -eq $null) {
	$path="$APIPrefix/graph-store"
	$apiGraphStore=New-AzureRmApiManagementApi -Context $management -Name "$APIPrefix - Graph Store" -ServiceUrl $serviceUrl -Protocols @("https") -Path "/$path"
	New-AzureRmApiManagementOperation -Context $management -ApiId $apiGraphStore.ApiId -Name "Get" -Method "GET" -UrlTemplate "/*"
	New-AzureRmApiManagementOperation -Context $management -ApiId $apiGraphStore.ApiId -Name "Post" -Method "POST" -UrlTemplate "/*"
	New-AzureRmApiManagementOperation -Context $management -ApiId $apiGraphStore.ApiId -Name "Delete" -Method "DELETE" -UrlTemplate "/*"
	New-AzureRmApiManagementOperation -Context $management -ApiId $apiGraphStore.ApiId -Name "Put" -Method "PUT" -UrlTemplate "/*"
}

Log "Id Generator"
$apiIdGenerate=Get-AzureRmApiManagementApi -Context $management | where ServiceUrl -EQ $idGeneratorUrl
if ($apiIdGenerate -eq $null) {
	$path="$APIPrefix/id/generate"
	$apiIdGenerate=New-AzureRmApiManagementApi -Context $management -Name "$APIPrefix - Id Generator" -ServiceUrl $idGeneratorUrl -Protocols @("https") -Path "/$path"
	$operationIdGenerate=New-AzureRmApiManagementOperation -Context $management -ApiId $apiIdGenerate.ApiId -Name "Get" -Method "GET" -UrlTemplate "/"
	$idGenerateGETPolicy=Get-Content -Path "$PoliciesFolderLocation\IdGenerateGET.xml" -Raw
	Set-AzureRmApiManagementPolicy -Context $management -ApiId $apiIdGenerate.ApiId -OperationId $operationIdGenerate.OperationId -Policy ($idGenerateGETPolicy -f "{{$APIPrefix-IdGeneratorKey}}")
}

$requestJMX=New-Object -TypeName Microsoft.Azure.Commands.ApiManagement.ServiceManagement.Models.PsApiManagementRequest -Property @{
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
Log "Java Management GraphDB Master"
$serviceUrl="http://10.0.$GraphDBsubnetIP3rdGroup.30/jolokia"
$apiJMX=Get-AzureRmApiManagementApi -Context $management | where ServiceUrl -EQ $serviceUrl
if ($apiJMX -eq $null) {
	$path="$APIPrefix/jolokia/master"
	$apiJMX=New-AzureRmApiManagementApi -Context $management -Name "$APIPrefix - Java Management GraphDB Master" -ServiceUrl $serviceUrl -Protocols @("https") -Path "/$path"
	$operationJMX=New-AzureRmApiManagementOperation -Context $management -ApiId $apiJMX.ApiId -Name "Post" -Method "POST" -UrlTemplate "/" -Request $requestJMX
	New-AzureRmApiManagementProperty -Context $management -Name "$APIPrefix-JMXUserName" -Value "$JMXUserName" -Secret
	New-AzureRmApiManagementProperty -Context $management -Name "$APIPrefix-MasterJolokiaSecret" -Value "$MasterJolokiaSecret" -Secret
	Set-AzureRmApiManagementPolicy -Context $management -ApiId $apiJMX.ApiId -OperationId $operationJMX.OperationId -Policy ($jmxPOSTPolicy -f "{{$APIPrefix-JMXUserName}}", "{{$APIPrefix-MasterJolokiaSecret}}")
}
    

Log "RDF4J Master"
$serviceUrl="http://10.0.$GraphDBsubnetIP3rdGroup.30/"
$apiRDF4J=Get-AzureRmApiManagementApi -Context $management | where {($_.ServiceUrl -EQ $serviceUrl) -and ($_.Name -match "RDF4J")}
if ($apiRDF4J -eq $null) {
	$path="$APIPrefix/rdf4j/master"
	$apiRDF4J=New-AzureRmApiManagementApi -Context $management -Name "$APIPrefix - RDF4J Master" -ServiceUrl $serviceUrl -Protocols @("https") -Path "/$path"
	New-AzureRmApiManagementOperation -Context $management -ApiId $apiRDF4J.ApiId -Name "Get" -Method "GET" -UrlTemplate "/*"
	New-AzureRmApiManagementOperation -Context $management -ApiId $apiRDF4J.ApiId -Name "Post" -Method "POST" -UrlTemplate "/*"
}

Log "Create new API Products"
$workbenchPassword=[Guid]::NewGuid()
New-AzureRmApiManagementProperty -Context $management -Name "$APIPrefix-WorkbenchAuthorization" -Value ([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("workbench:$workbenchPassword"))) -Secret
$allProducts=@(
    New-Object -TypeName PSObject -Property @{
		"Id"="Website";
        "ProductName"="$APIPrefix - Parliament [Beta website]";
		"HasSubscription"=$true;
        "APIs"=@($apiFixedQuery.ApiId,$apiSearch.ApiId);
    }
    New-Object -TypeName PSObject -Property @{
		"Id"="FixedQuery";
        "ProductName"="$APIPrefix - Parliament [Fixed Query]";
		"HasSubscription"=$true;
        "APIs"=@($apiSPARQL.ApiId)
    }
    New-Object -TypeName PSObject -Property @{
		"Id"="Orchestration";
        "ProductName"="$APIPrefix - Parliament [Orchestration]";
		"HasSubscription"=$true;
        "APIs"=@($apiGraphStore.ApiId,$apiIdGenerate.ApiId)
    }
    New-Object -TypeName PSObject -Property @{
		"Id"="Availability";
        "ProductName"="$APIPrefix - Parliament [Availability]";
		"HasSubscription"=$true;
        "APIs"=@($apiIdGenerate.ApiId,$apiSearch.ApiId,$apiSPARQL.ApiId,$apiFixedQuery.ApiId)
    }
    New-Object -TypeName PSObject -Property @{
		"Id"="Release";
        "ProductName"="$APIPrefix - Parliament [Release]";
		"HasSubscription"=$true;
        "APIs"=@($apiIdGenerate.ApiId,$apiRDF4J.ApiId,$apiJMX.ApiId)
    }
	New-Object -TypeName PSObject -Property @{
		"Id"="PublicFixedQuery";
        "ProductName"="$APIPrefix - Public [Fixed Query]";
		"HasSubscription"=$false;
		"PolicyXML"=(Get-Content -Path "$PoliciesFolderLocation\FixedQueryPublic.xml" -Raw)
        "APIs"=@($apiFixedQuery.ApiId)
    }
	New-Object -TypeName PSObject -Property @{
		"Id"="Workbench";
        "ProductName"="$APIPrefix - Parliament [Workbench]";
		"HasSubscription"=$false;
		"PolicyXML"=((Get-Content -Path "$PoliciesFolderLocation\WorkbenchParliament.xml" -Raw) -f "{{$APIPrefix-WorkbenchAuthorization}}");
        "APIs"=@($apiRDF4J.ApiId)
    }
	New-Object -TypeName PSObject -Property @{
		"Id"="Photo";
        "ProductName"="$APIPrefix - Parliament [Photo]";
		"HasSubscription"=$true;
        "APIs"=@($apiFixedQuery.ApiId)
    }
	New-Object -TypeName PSObject -Property @{
		"Id"="PublicPhoto";
        "ProductName"="$APIPrefix - Public [Photo]";
		"HasSubscription"=$false;
        "APIs"=@($apiPhoto.ApiId)
    }
	New-Object -TypeName PSObject -Property @{
		"Id"="OData";
        "ProductName"="$APIPrefix - Parliament [OData]";
		"HasSubscription"=$true;
        "APIs"=@($apiSPARQL.ApiId)
    }
	New-Object -TypeName PSObject -Property @{
		"Id"="PublicOData";
        "ProductName"="$APIPrefix - Public [OData]";
		"HasSubscription"=$false;
        "APIs"=@($apiOData.ApiId)
    }
)

foreach ($product in $allProducts){
	Log "Create $($product.ProductName)"
	if ($product.HasSubscription -eq $true) {
		$apiProduct=New-AzureRmApiManagementProduct -Context $management -Title $product.ProductName -Description "For parliamentary use only." -ApprovalRequired $true -SubscriptionsLimit 1 -SubscriptionRequired $true
	}
	else {
		$apiProduct=New-AzureRmApiManagementProduct -Context $management -Title $product.ProductName -Description "For parliamentary use only." -ApprovalRequired $false -SubscriptionRequired $false
	}
	if ($product.PolicyXML) {
		Set-AzureRmApiManagementPolicy -Context $management -ProductId $apiProduct.ProductId -Policy $product.PolicyXML
	}
	foreach ($api in $product.APIs) {
		Log "Add API $api"
		Add-AzureRmApiManagementApiToProduct -Context $management -ProductId $apiProduct.ProductId -ApiId $api
	}
}


Log "Job well done!"