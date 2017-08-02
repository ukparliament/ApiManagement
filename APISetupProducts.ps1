<#
.SYNOPSIS
Creates API Product and assigns APIs.

.DESCRIPTION
Creates API Product and assigns APIs.

.PARAMETER APIResourceGroupName
Name of the Resource Group where the API Management is.

.PARAMETER APIManagementName
Name of the API Management.

.NOTES
This script is for use as a part of deployment in VSTS only.
#>

Param(
    [Parameter(Mandatory=$true)] [string] $APIResourceGroupName,
    [Parameter(Mandatory=$true)] [string] $AzureFunctionsName,
    [Parameter(Mandatory=$true)] [string] $FixedQueryName,
	[Parameter(Mandatory=$true)] [string] $PhotoAPIName,
    [Parameter(Mandatory=$true)] [string] $SearchAPIName,
    [Parameter(Mandatory=$true)] [string] $APIManagementName,
	[Parameter(Mandatory=$true)] [int] $GraphDBsubnetIP3rdGroup,
    [Parameter(Mandatory=$true)] [string] $PoliciesFolderLocation,
	[Parameter(Mandatory=$true)] [ValidateSet("All", "Website", "FixedQuery", "Orchestration", "Availability", "Release", "Workbench", "Photo", "PublicFixedQuery", "PublicPhoto")] [string] $APIProductSelection,
	[Parameter(Mandatory=$true)][AllowEmptyString()] [string] $APIPrefix
)
$ErrorActionPreference = "Stop"
$graphDBsubnetIP2ndGroups=$(0,128)

function Log([Parameter(Mandatory=$true)][string]$LogText){
    Write-Host ("{0} - {1}" -f (Get-Date -Format "HH:mm:ss.fff"), $LogText)
}

Log "Get API Management context"
$management=New-AzureRmApiManagementContext -ResourceGroupName $APIResourceGroupName -ServiceName $APIManagementName

Log "Get APIs"

Log "Fixed Query"
$serviceUrl="https://$FixedQueryName.azurewebsites.net/"
$apiFixedQuery=Get-AzureRmApiManagementApi -Context $management | where ServiceUrl -EQ $serviceUrl

Log "Photo"
$serviceUrl="https://$PhotoAPIName.azurewebsites.net/"
$apiPhoto=Get-AzureRmApiManagementApi -Context $management | where ServiceUrl -EQ $serviceUrl

Log "Search"
$serviceUrl="https://$SearchAPIName.azurewebsites.net/"
$apiSearch=Get-AzureRmApiManagementApi -Context $management | where ServiceUrl -EQ $serviceUrl

$apiSPARQL=@()
for($i=0;$i -lt 2;$i++) {
    Log "Read-only SPARQL Endpoint Master $i"
	$serviceUrl="http://10.$($graphDBsubnetIP2ndGroups[$i]).$GraphDBsubnetIP3rdGroup.30/repositories/Master"
	$apiSPARQLN=Get-AzureRmApiManagementApi -Context $management | where ServiceUrl -EQ $serviceUrl
    $apiSPARQL+=$apiSPARQLN
}

Log "Graph Store"
$serviceUrl="http://10.$($graphDBsubnetIP2ndGroups[0]).$GraphDBsubnetIP3rdGroup.30/"
$apiGraphStore=Get-AzureRmApiManagementApi -Context $management | where where {($_.ServiceUrl -EQ $serviceUrl) -and ($_.Name -match "Store")}

Log "API Health"
$serviceUrl="https://$APIManagementName.portal.azure-api.net"
$apiHealth=Get-AzureRmApiManagementApi -Context $management | where ServiceUrl -EQ $serviceUrl

Log "Id Generator"
$apiIdGenerate=Get-AzureRmApiManagementApi -Context $management | where ServiceUrl -EQ $idGeneratorUrl

$apiJMX=@()
for($i=0;$i -lt 2;$i++) {
    Log "Java Management GraphDB Master $i"
	$serviceUrl="http://10.$($graphDBsubnetIP2ndGroups[$i]).$GraphDBsubnetIP3rdGroup.30/jolokia"
	$apiJMXN=Get-AzureRmApiManagementApi -Context $management | where ServiceUrl -EQ $serviceUrl
    $apiJMX+=$apiJMXN
}

$apiRDF4J=@()
for($i=0;$i -lt 2;$i++) {
    Log "RDF4J Master $i"
	$serviceUrl="http://10.$($graphDBsubnetIP2ndGroups[$i]).$GraphDBsubnetIP3rdGroup.30/"
	$apiRDF4JN=Get-AzureRmApiManagementApi -Context $management | where {($_.ServiceUrl -EQ $serviceUrl) -and ($_.Name -match "RDF4J")}
    $apiRDF4J+=$apiRDF4JN
}

Log "Create new API Products"

$allProducts=@(
    New-Object -TypeName PSObject -Property @{
		"Id"="Website";
        "ProductName"="$($APIPrefix)Parliament - Beta website";
		"HasSubscription"=$true;
        "APIs"=@($apiFixedQuery.ApiId,$apiSearch.ApiId);
    }
    New-Object -TypeName PSObject -Property @{
		"Id"="FixedQuery";
        "ProductName"="$($APIPrefix)Parliament - Fixed Query";
		"HasSubscription"=$true;
        "APIs"=@($apiSPARQL[0].ApiId)
    }
    New-Object -TypeName PSObject -Property @{
		"Id"="Orchestration";
        "ProductName"="$($APIPrefix)Parliament - Orchestration";
		"HasSubscription"=$true;
        "APIs"=@($apiGraphStore.ApiId,$apiIdGenerate.ApiId)
    }
    New-Object -TypeName PSObject -Property @{
		"Id"="Availability";
        "ProductName"="$($APIPrefix)Parliament - Availability";
		"HasSubscription"=$true;
        "APIs"=@($apiIdGenerate.ApiId,$apiSearch.ApiId,$apiSPARQL[0].ApiId,$apiSPARQL[1].ApiId,$apiHealth.ApiId,$apiFixedQuery.ApiId)
    }
    New-Object -TypeName PSObject -Property @{
		"Id"="Release";
        "ProductName"="$($APIPrefix)Parliament - Release";
		"HasSubscription"=$true;
        "APIs"=@($apiIdGenerate.ApiId,$apiRDF4J[0].ApiId,$apiRDF4J[1].ApiId,$apiJMX[0].ApiId,$apiJMX[1].ApiId)
    }
	New-Object -TypeName PSObject -Property @{
		"Id"="PublicFixedQuery";
        "ProductName"="$($APIPrefix)Public - Fixed Query";
		"HasSubscription"=$false;
		"PolicyXML"=(Get-Content -Path "$PoliciesFolderLocation\FixedQueryPublic.xml" -Raw)
        "APIs"=@($apiFixedQuery.ApiId)
    }
	New-Object -TypeName PSObject -Property @{
		"Id"="Workbench";
        "ProductName"="$($APIPrefix)Parliament - Workbench";
		"HasSubscription"=$false;
		"PolicyXML"=((Get-Content -Path "$PoliciesFolderLocation\WorkbenchParliament.xml" -Raw) -f [Guid]::NewGuid());
        "APIs"=@($apiRDF4J[0].ApiId)
    }
	New-Object -TypeName PSObject -Property @{
		"Id"="Photo";
        "ProductName"="$($APIPrefix)Parliament - Photo";
		"HasSubscription"=$true;
        "APIs"=@($apiSPARQL[0].ApiId)
    }
	New-Object -TypeName PSObject -Property @{
		"Id"="PublicPhoto";
        "ProductName"="$($APIPrefix)Public - Photo";
		"HasSubscription"=$false;
        "APIs"=@($apiPhoto.ApiId)
    }
)

foreach ($product in $allProducts){
	if (($product.Id -eq $APIProductSelection) -or ($APIProductSelection -eq "All")) {
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
}

Log "Job well done!"