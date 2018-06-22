<#
.SYNOPSIS
Merges OpenApi definitions.

.DESCRIPTION
Merges OpenApi definitions from Photo, Query and OData projects.

.NOTES
This script is for use as a part of deployment in VSTS only.
#>

Param(
    [Parameter(Mandatory=$true)] [string] $ODataFileLocation,
    [Parameter(Mandatory=$true)] [string] $QueryFileLocation,
	[Parameter(Mandatory=$true)] [string] $PhotoFileLocation,
	[Parameter(Mandatory=$true)] [string] $MergedOpenApiFileLocation
)
$ErrorActionPreference = "Stop"

function Log([Parameter(Mandatory=$true)][string]$LogText){
    Write-Host ("{0} - {1}" -f (Get-Date -Format "HH:mm:ss.fff"), $LogText)
}

Log "Read files"
$odataApi=Get-Content $ODataFileLocation | ConvertFrom-Json
$queryApi=Get-Content $QueryFileLocation | ConvertFrom-Json
$photoApi=Get-Content $PhotoFileLocation | ConvertFrom-Json

$api= New-Object -TypeName PSCustomObject

Log "Add paths"
Add-Member -InputObject $api -Name "paths" -Value (New-Object -TypeName PSCustomObject) -MemberType NoteProperty
function Set-OperationPath([Parameter(Mandatory=$true)]$Source) {
    $basePath=[System.Uri]::new($Source.servers[0].url).AbsolutePath
    foreach($path in Get-Member -InputObject $Source.paths -MemberType NoteProperty){
        $method=Select-Object -InputObject $Source.paths -ExpandProperty $path.Name
        Add-Member -InputObject $api.paths -Name "$($BasePath)$($path.Name)" -Value $method -MemberType NoteProperty
    }
}
Set-OperationPath -Source $odataApi 
Set-OperationPath -Source $photoApi
Set-OperationPath -Source $queryApi 

Log "Add components"
Add-Member -InputObject $api -Name "components" -Value (New-Object -TypeName PSCustomObject) -MemberType NoteProperty
function Set-Component([Parameter(Mandatory=$true)]$Source) {
    foreach($propertyName in @("responses","parameters")) {        
        if (($Source.components) -and ($Source.components.$propertyName)) {
            if ($api.components.$propertyName -eq $null) {
                Add-Member -InputObject $api.components -Name $propertyName -Value (New-Object -TypeName PSCustomObject) -MemberType NoteProperty
            }
            foreach($response in Get-Member -InputObject $Source.components.$propertyName -MemberType NoteProperty){    
                $namedResponse=Select-Object -InputObject $Source.components.$propertyName -ExpandProperty $response.Name
                Add-Member -InputObject $api.components.$propertyName -Name $response.Name -Value $namedResponse -MemberType NoteProperty -Force
            }
        }
    }
}
Set-Component -Source $odataApi 
Set-Component -Source $photoApi
Set-Component -Source $queryApi 

Log "Set top level information"
Add-Member -InputObject $api -Name "openapi" -Value $odataApi.openapi -MemberType NoteProperty
Add-Member -InputObject $api -Name "info" -Value $odataApi.info -MemberType NoteProperty
Add-Member -InputObject $api -Name "servers" -Value $odataApi.servers -MemberType NoteProperty
$api.info.title="UK Parliament API"
$api.info.description="Publicly available API"
$api.servers[0].url="https://api.parliament.uk"

ConvertTo-Json $api -Compress -Depth 99 | Set-Content -Path "$MergedOpenApiFileLocation"

Log "Job well done!"