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
    [Parameter(Mandatory=$true)] [string] $PoliciesFolderLocation
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

Log "Remove examples"

Log "Remove subscriptions to API Products"
Get-AzureRmApiManagementSubscription -Context $management | Remove-AzureRmApiManagementSubscription -Context $management
Log "Remove API Products"
Get-AzureRmApiManagementProduct -Context $management | Remove-AzureRmApiManagementProduct -Context $management
Log "Remove endpoints"
Get-AzureRmApiManagementApi -Context $management | Select-Object ApiId -ExpandProperty ApiId | Remove-AzureRmApiManagementApi -Context $management

Log "Create APIs"

Log "Fixed Query"
$apiFixedQuery=New-AzureRmApiManagementApi -Context $management -Name "Fixed Query" -ServiceUrl "https://$FixedQueryName.azurewebsites.net/" -Protocols @("https") -Path "/fixed-query"
$operationFixedQuery=New-AzureRmApiManagementOperation -Context $management -ApiId $apiFixedQuery.ApiId -Name "Get" -Method "GET" -UrlTemplate "/*"
Set-AzureRmApiManagementPolicy -Context $management -ApiId $apiFixedQuery.ApiId -OperationId $operationFixedQuery.OperationId -PolicyFilePath "$PoliciesFolderLocation\FixedQueryGET.xml"

Log "Photo"
$apiPhoto=New-AzureRmApiManagementApi -Context $management -Name "Photo" -ServiceUrl "https://$PhotoAPIName.azurewebsites.net/" -Protocols @("https") -Path "/photo"
$operationPhoto=New-AzureRmApiManagementOperation -Context $management -ApiId $apiPhoto.ApiId -Name "Get" -Method "GET" -UrlTemplate "/*"
Set-AzureRmApiManagementPolicy -Context $management -ApiId $apiPhoto.ApiId -OperationId $operationPhoto.OperationId -PolicyFilePath "$PoliciesFolderLocation\PhotoGET.xml"

Log "Search"
$apiSearch=New-AzureRmApiManagementApi -Context $management -Name "Search" -ServiceUrl "https://$SearchAPIName.azurewebsites.net/" -Protocols @("https") -Path "/search"
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

$apiSPARQL=@()
for($i=0;$i -lt 2;$i++) {
    Log "Read-only SPARQL Endpoint Master $i"
    $apiSPARQLN=New-AzureRmApiManagementApi -Context $management -Name "Read-only SPARQL Endpoint $i" -ServiceUrl "http://10.$($graphDBsubnetIP2ndGroups[$i]).$GraphDBsubnetIP3rdGroup.30/repositories/Master" -Protocols @("https") -Path "/sparql-endpoint/master-$i"
    New-AzureRmApiManagementOperation -Context $management -ApiId $apiSPARQLN.ApiId -Name "Get" -Method "GET" -UrlTemplate "/*"
    $operationSPARQL=New-AzureRmApiManagementOperation -Context $management -ApiId $apiSPARQLN.ApiId -Name "Post" -Method "POST" -UrlTemplate "/"
    Set-AzureRmApiManagementPolicy -Context $management -ApiId $apiSPARQLN.ApiId -OperationId $operationSPARQL.OperationId -PolicyFilePath "$PoliciesFolderLocation\SPARQLEndpointPOST.xml"
    $apiSPARQL+=$apiSPARQLN
}

Log "Graph Store"
$apiGraphStore=New-AzureRmApiManagementApi -Context $management -Name "Graph Store" -ServiceUrl "http://10.$($graphDBsubnetIP2ndGroups[0]).$GraphDBsubnetIP3rdGroup.30/" -Protocols @("https") -Path "/graph-store"
New-AzureRmApiManagementOperation -Context $management -ApiId $apiGraphStore.ApiId -Name "Get" -Method "GET" -UrlTemplate "/*"
New-AzureRmApiManagementOperation -Context $management -ApiId $apiGraphStore.ApiId -Name "Post" -Method "POST" -UrlTemplate "/*"
New-AzureRmApiManagementOperation -Context $management -ApiId $apiGraphStore.ApiId -Name "Delete" -Method "DELETE" -UrlTemplate "/*"
New-AzureRmApiManagementOperation -Context $management -ApiId $apiGraphStore.ApiId -Name "Put" -Method "PUT" -UrlTemplate "/*"

Log "API Health"
$apiHealth=New-AzureRmApiManagementApi -Context $management -Name "API Health" -ServiceUrl "https://$APIManagementName.portal.azure-api.net" -Protocols @("https") -Path "/api-health"
$operationAPIHealth=New-AzureRmApiManagementOperation -Context $management -ApiId $apiHealth.ApiId -Name "Get" -Method "GET" -UrlTemplate "/*"
Set-AzureRmApiManagementPolicy -Context $management -ApiId $apiHealth.ApiId -OperationId $operationAPIHealth.OperationId -PolicyFilePath "$PoliciesFolderLocation\APIHealthGET.xml"

Log "Id Generator"
$apiIdGenerate=New-AzureRmApiManagementApi -Context $management -Name "Id Generator" -ServiceUrl $idGeneratorUrl -Protocols @("https") -Path "/id/generate"
$operationIdGenerate=New-AzureRmApiManagementOperation -Context $management -ApiId $apiIdGenerate.ApiId -Name "Get" -Method "GET" -UrlTemplate "/"
Set-AzureRmApiManagementPolicy -Context $management -ApiId $apiIdGenerate.ApiId -OperationId $operationIdGenerate.OperationId -PolicyFilePath "$PoliciesFolderLocation\IdGenerateGET.xml"

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
    $apiJMXN=New-AzureRmApiManagementApi -Context $management -Name "Java Management GraphDB Master $i" -ServiceUrl "http://10.$($graphDBsubnetIP2ndGroups[$i]).$GraphDBsubnetIP3rdGroup.30/jolokia" -Protocols @("https") -Path "/jolokia/master-$i"
    $operationJMXN=New-AzureRmApiManagementOperation -Context $management -ApiId $apiJMXN.ApiId -Name "Post" -Method "POST" -UrlTemplate "/" -Request $requestJMXN
    Set-AzureRmApiManagementPolicy -Context $management -ApiId $apiJMXN.ApiId -OperationId $operationJMXN.OperationId -Policy ($jmxPOSTPolicy -f $JMXUserName, $jolokias[$i])
    $apiJMX+=$apiJMXN
}

$apiRDF4J=@()
for($i=0;$i -lt 2;$i++) {
    Log "RDF4J Master $i"
    $apiRDF4JN=New-AzureRmApiManagementApi -Context $management -Name "RDF4J Master $i" -ServiceUrl "http://10.$($graphDBsubnetIP2ndGroups[$i]).$GraphDBsubnetIP3rdGroup.30/" -Protocols @("https") -Path "/rdf4j/master-$i"
    New-AzureRmApiManagementOperation -Context $management -ApiId $apiRDF4JN.ApiId -Name "Get" -Method "GET" -UrlTemplate "/*"
    New-AzureRmApiManagementOperation -Context $management -ApiId $apiRDF4JN.ApiId -Name "Post" -Method "POST" -UrlTemplate "/*"
    $apiRDF4J+=$apiRDF4JN
}

Log "Create new API Products"

$allProducts=@(
    New-Object -TypeName PSObject -Property @{
        "ProductName"="Parliament - Beta website";
		"HasSubscription"=$true;
        "APIs"=@($apiFixedQuery.ApiId,$apiSearch.ApiId);
    }
    New-Object -TypeName PSObject -Property @{
        "ProductName"="Parliament - Fixed Query";
		"HasSubscription"=$true;
        "APIs"=@($apiSPARQL[0].ApiId)
    }
    New-Object -TypeName PSObject -Property @{
        "ProductName"="Parliament - Orchestration";
		"HasSubscription"=$true;
        "APIs"=@($apiGraphStore.ApiId,$apiIdGenerate.ApiId)
    }
    New-Object -TypeName PSObject -Property @{
        "ProductName"="Parliament - Availability";
		"HasSubscription"=$true;
        "APIs"=@($apiIdGenerate.ApiId,$apiSearch.ApiId,$apiSPARQL[0].ApiId,$apiSPARQL[1].ApiId,$apiHealth.ApiId,$apiFixedQuery.ApiId)
    }
    New-Object -TypeName PSObject -Property @{
        "ProductName"="Parliament - Release";
		"HasSubscription"=$true;
        "APIs"=@($apiIdGenerate.ApiId,$apiRDF4J[0].ApiId,$apiRDF4J[1].ApiId,$apiJMX[0].ApiId,$apiJMX[1].ApiId)
    }
	New-Object -TypeName PSObject -Property @{
        "ProductName"="Public - Fixed Query";
		"HasSubscription"=$false;
		"PolicyXML"=(Get-Content -Path "$PoliciesFolderLocation\FixedQueryPublic.xml" -Raw)
        "APIs"=@($apiFixedQuery.ApiId)
    }
	New-Object -TypeName PSObject -Property @{
        "ProductName"="Parliament - Workbench";
		"HasSubscription"=$false;
		"PolicyXML"=((Get-Content -Path "$PoliciesFolderLocation\WorkbenchParliament.xml" -Raw) -f [Guid]::NewGuid());
        "APIs"=@($apiRDF4J[0].ApiId)
    }
	New-Object -TypeName PSObject -Property @{
        "ProductName"="Public - Photo";
		"HasSubscription"=$false;
        "APIs"=@($apiPhoto.ApiId)
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

$apiProductAvailability=Get-AzureRmApiManagementProduct -Context $management -Title "Parliament - Availability"

Log "Setting variables to use during deployment"
$subscriptionAvailability=Get-AzureRmApiManagementSubscription -Context $management -ProductId $apiProductAvailability.ProductId
Write-Host "##vso[task.setvariable variable=APISubscriptionAvailability]$($subscriptionAvailability.PrimaryKey)"

Log "Job well done!"