<#
.SYNOPSIS
Detects generic part of the name and IP's 3rd group associated with specified environment.

.DESCRIPTION
Detects generic part of the name and IP's 3rd group associated with specified environment.

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
	[Parameter(Mandatory=$true)] [string] $APIPrefix
)
$ErrorActionPreference = "Stop"

function Log([Parameter(Mandatory=$true)][string]$LogText){
    Write-Host ("{0} - {1}" -f (Get-Date -Format "HH:mm:ss.fff"), $LogText)
}

Log "Get API Management context"
$management=New-AzureRmApiManagementContext -ResourceGroupName $APIResourceGroupName -ServiceName $APIManagementName

Log "Detects generic name for $APIPrefix"
$apiFixedQuery=Get-AzureRmApiManagementApi -Context $management | Where-Object {($_.ApiVersion -EQ "$APIPrefix") -and ($_.Name -EQ "Fixed Query")}
$genericName=$apiFixedQuery.ServiceUrl.Substring(18,$apiFixedQuery.ServiceUrl.IndexOf('.')-18)

Log "Detects IP's 3rd group for $APIPrefix"
$apiGraphStore=Get-AzureRmApiManagementApi -Context $management | Where-Object {($_.ApiVersion -EQ "$APIPrefix") -and ($_.Name -EQ "RDF4J")}
$graphDBsubnetIP3rdGroup=$apiGraphStore.ServiceUrl.Split('.')[2]

Log "Setting variables to use during deployment"
Write-Host "##vso[task.setvariable variable=GenericName]$genericName"
Write-Host "##vso[task.setvariable variable=GraphDBsubnetIP3rdGroup]$graphDBsubnetIP3rdGroup"

Log "Job well done!"