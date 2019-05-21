<#
.SYNOPSIS
Swap environments.

.DESCRIPTION
Swap APIs, named values (API Management), logic app, web apps settings.

.PARAMETER APIResourceGroupName
Name of the Resource Group where the API Management is.

.PARAMETER APIManagementName
Name of the API Management.

.NOTES
This script is for use as a part of deployment in VSTS only.
#>

<#TODO
switch
    id generate
        backend
        policy - named value 
    when switching to live original has to be updated
    network security group - indexing and search
new env
    api mngmt: update 3rd ip section
    api mngmt: update api domains
#>
Param(
    [Parameter(Mandatory=$true)] [string] $APIResourceGroupName,
    [Parameter(Mandatory=$true)] [string] $APIManagementName,
    [Parameter(Mandatory=$true)] [string] $APIPrefix1,
    [Parameter(Mandatory=$true)] [string] $APIPrefix2,
    [Parameter(Mandatory=$true)] [string] $GenericName1,
    [Parameter(Mandatory=$true)] [string] $GenericName2,
    [Parameter(Mandatory=$true)] [string] $PowershellModuleDirectory
)
$ErrorActionPreference = "Stop"

Import-Module -Name $PowershellModuleDirectory\Write-LogToHost.psm1

Write-LogToHost "Swap $APIPrefix1 ($GenericName1) with $APIPrefix2 ($GenericName2)"

$apiNames=@("Java Management GraphDB Master","OData","Photo","Query","RDF4J","Search","SPARQL")
$appNames=@("fixedquery","odata","photo","func")

Write-LogToHost "Get API Management context"
$management=New-AzureRmApiManagementContext -ResourceGroupName $APIResourceGroupName -ServiceName $APIManagementName

Write-LogToHost "Swap apis"
foreach($name in $apiNames) {
    Write-LogToHost "Api: $name"
    $api1=Get-AzureRmApiManagementApi -Context $management -Name $name | Where-Object ApiVersion -EQ $APIPrefix1
    $api2=Get-AzureRmApiManagementApi -Context $management -Name $name | Where-Object ApiVersion -EQ $APIPrefix2
    Set-AzureRmApiManagementApi -Context $management -ApiId $api1.ApiId -Name $name -Protocols $api2.Protocols -ServiceUrl $api2.ServiceUrl
    Set-AzureRmApiManagementApi -Context $management -ApiId $api2.ApiId -Name $name -Protocols $api1.Protocols -ServiceUrl $api1.ServiceUrl
}

Write-LogToHost "Swap policy for id generator"
$api1=Get-AzureRmApiManagementApi -Context $management -Name "Id" | Where-Object ApiVersion -EQ $APIPrefix1
$operation1=Get-AzureRmApiManagementOperation -Context $management -ApiId $api1.ApiId | Where-Object Name -EQ "Generate"
$policy1=Get-AzureRmApiManagementPolicy -Context $management -ApiId $api1.ApiId -OperationId $operation1.OperationId

$api2=Get-AzureRmApiManagementApi -Context $management -Name "Id" | Where-Object ApiVersion -EQ $APIPrefix2
$operation2=Get-AzureRmApiManagementOperation -Context $management -ApiId $api2.ApiId | Where-Object Name -EQ "Generate"
$policy2=Get-AzureRmApiManagementPolicy -Context $management -ApiId $api2.ApiId -OperationId $operation2.OperationId

Set-AzureRmApiManagementPolicy -Context $management -ApiId $api1.ApiId -OperationId $operation1.OperationId -Policy $policy2
Set-AzureRmApiManagementPolicy -Context $management -ApiId $api2.ApiId -OperationId $operation2.OperationId -Policy $policy1

Write-LogToHost "Named value swap"
$namedValue1=Get-AzureRmApiManagementProperty -Context $management -Name "$APIPrefix1-IdGeneratorKey"
$namedValue2=Get-AzureRmApiManagementProperty -Context $management -Name "$APIPrefix2-IdGeneratorKey"
Set-AzureRmApiManagementProperty -Context $management -PropertyId $namedValue1.PropertyId -Value $namedValue2.Value -Secret $true
Set-AzureRmApiManagementProperty -Context $management -PropertyId $namedValue2.PropertyId -Value $namedValue1.Value -Secret $true

Write-LogToHost "Logic App (epetition swap)"
$logicApp1=Get-AzureRmLogicApp -ResourceGroupName "data-orchestration$GenericName1" -Name "getlist-epetition"
$logicApp2=Get-AzureRmLogicApp -ResourceGroupName "data-orchestration$GenericName2" -Name "getlist-epetition"
$k1=$logicApp1.Definition.Property("actions").Property("GetMaxUpdatedAt").Property("inputs").Property("headers").Property("Ocp-Apim-Subscription-Key").Value.Value
$k2=$logicApp2.Definition.Property("actions").Property("GetMaxUpdatedAt").Property("inputs").Property("headers").Property("Ocp-Apim-Subscription-Key").Value.Value
$v1=$logicApp1.Definition.Property("actions").Property("GetMaxUpdatedAt").Property("inputs").Property("headers").Property("Api-Version").Value.Value
$v2=$logicApp2.Definition.Property("actions").Property("GetMaxUpdatedAt").Property("inputs").Property("headers").Property("Api-Version").Value.Value
$logicApp1.Definition.Property("actions").Property("GetMaxUpdatedAt").Property("inputs").Property("headers").Property("Ocp-Apim-Subscription-Key").Value.Value=$k2
$logicApp2.Definition.Property("actions").Property("GetMaxUpdatedAt").Property("inputs").Property("headers").Property("Ocp-Apim-Subscription-Key").Value.Value=$k1
$logicApp1.Definition.Property("actions").Property("GetMaxUpdatedAt").Property("inputs").Property("headers").Property("Api-Version").Value.Value=$v2
$logicApp2.Definition.Property("actions").Property("GetMaxUpdatedAt").Property("inputs").Property("headers").Property("Api-Version").Value.Value=$v1
Set-AzureRmLogicApp -ResourceGroupName "data-orchestration$genericName1" -Name "getlist-epetition" -Definition $logicApp1.Definition -Force -Verbose
Set-AzureRmLogicApp -ResourceGroupName "data-orchestration$genericName2" -Name "getlist-epetition" -Definition $logicApp2.Definition -Force -Verbose

Write-LogToHost "App settings swap"
foreach ($name in $appNames) {
    Write-LogToHost "App: $name"
    $webApp1=Get-AzureRmWebApp -Name "$name$genericName1"
    $webApp2=Get-AzureRmWebApp -Name "$name$genericName2"
    $settings1=@{}
    foreach($set in $webApp1.SiteConfig.AppSettings){ 
        $settings1[$set.Name]=$set.Value
    }
    $settings2=@{}
    foreach($set in $webApp2.SiteConfig.AppSettings){ 
        $settings2[$set.Name]=$set.Value
    }

    $appSettingsNames=@("SubscriptionKey","ApiVersion")
    if ($name -eq "photo"){
        $appSettingsNames=@("Query__SubscriptionKey","Query__ApiVersion")
    }
    foreach ($settingName in $appSettingsNames) {
        $s1=$settings1[$settingName]
        $s2=$settings2[$settingName]
        $settings1[$settingName]=$s2
        $settings2[$settingName]=$s1    
    }    

    Set-AzureRmWebApp -ResourceGroupName $($webApp1.ResourceGroup) -Name "$name$genericName1" -AppSettings $settings1
    Set-AzureRmWebApp -ResourceGroupName $($webApp2.ResourceGroup) -Name "$name$genericName2" -AppSettings $settings2
}

Write-LogToHost "Connection string swap"
$webApp1=Get-AzureRmWebApp -Name "func$genericName1"
$webApp2=Get-AzureRmWebApp -Name "func$genericName2"
$connections1 = @{}
foreach($connection in $webApp1.SiteConfig.ConnectionStrings){
    $connections1[$connection.Name]=@{Type=if ($connection.Type -eq $null){"Custom"}else{$connection.Type.ToString()};Value=$connection.ConnectionString}
}
$connections2 = @{}
foreach($connection in $webApp2.SiteConfig.ConnectionStrings){
    $connections2[$connection.Name]=@{Type=if ($connection.Type -eq $null){"Custom"}else{$connection.Type.ToString()};Value=$connection.ConnectionString}
}

$v1=$connections1["InterimSqlServer"]
$v2=$connections2["InterimSqlServer"] 
$connections1["InterimSqlServer"]=$v2
$connections2["InterimSqlServer"]=$v1
Set-AzureRmWebApp -ResourceGroupName $($webApp1.ResourceGroup) -Name "func$genericName1" -ConnectionStrings $connections1
Set-AzureRmWebApp -ResourceGroupName $($webApp2.ResourceGroup) -Name "func$genericName2" -ConnectionStrings $connections2

Write-LogToHost "Job well done!"