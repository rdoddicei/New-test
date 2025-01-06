[CmdletBinding()]
Param(
[Parameter(Mandatory=$True,Position=1)]
    [string]$customer,
[Parameter(Mandatory=$True,Position=2)]
    [string]$customerPassword,
[Parameter(Mandatory=$True,Position=3)]
    [string]$reportSrcRoot,
[Parameter(Mandatory=$True,Position=4)]
    [string]$reportDestRoot,
[Parameter(Mandatory=$True,Position=5)]
    [string]$targetServerUrl, 
[Parameter(Mandatory=$True,Position=6)]
    [string]$listenerName,
[Parameter(Mandatory=$True,Position=7)]
    [bool]$deployTemplateReports,
[Parameter(Mandatory=$True,Position=8)]
    [string]$deploymentMode,
[Parameter(Mandatory=$True,Position=9)]
    [string]$dataSourceUserName

    
<#
[Parameter(Mandatory=$True,Position=9)]
    [string]$includeDataSources,
[Parameter(Mandatory=$True,Position=10)]
    [string]$includeDataSets,
[Parameter(Mandatory=$True,Position=11)]
    [string]$includeImages,
[Parameter(Mandatory=$True,Position=12)]
    [string]$includeReports
#>
)

<# Example command

./DeployReportsForR4.ps1  -customer devdenalitest26 -reportSrcRoot H:\DeploymentSource\r4sr0\reports  -reportDestRoot H:\CustomerDeployments -targetServerUrl http://denali-sql-0/reportserver -listenerName denali-agl1

#>


#when working comment out below
<#
$customer="devdenalitest30"
$dataSourceUserName =
$reportSrcRoot="H:\DeploymentSource\r4sr0\reports"
$reportDestRoot = "H:\CustomerDeployments"
$targetServerUrl = "http://denali-sql-0/reportserver"
$listenerName="denali-agl1"
$deployTemplateReports = $false
$deploymentMode = "BPT"
$customerPassword = $serviceAccountLoginPassword
#>


echo "PARAMETERS:"
echo "customer = $customer"
echo "reportSrcRoot = $reportSrcRoot"
echo "reportDestRoot = $reportDestRoot"
echo "targetServerUrl = $targetServerUrl"
echo "listenerName = $listenerName"
echo "dataSourceUser = $dataSourceUserName"


#Variables
#$reportSrcPath = Join-Path -Path $reportSrcRoot -ChildPath "Reports"
$reportSrcPath = $reportSrcRoot #H:\deploymentsource\versionfolder\reports
$reportDestPath = Join-Path -Path $reportDestRoot -ChildPath $customer | Join-Path -ChildPath "ReportDeployments"#H:\customerdeployments\customer\reportdeployments
#$reportDestPath = Join-Path -Path $reportDestRoot -ChildPath $customer | Join-Path -ChildPath "ReportDeployments"
$databaseName=$customer + '_RAMDB'
$connectionString = "Data Source=" + $listenerName + ";Initial Catalog=" + $databaseName + ";ApplicationIntent=ReadOnly"
$targetServerVersion = "SSRS2016" #"SQL Server 2008 R2, 2012 or 2014" 
#$targetDataSourceFolder = "Data Sources/" + $customer
$targetDataSourceFolder = $customer + "/Data Sources"  

#doing this in main script
<#
echo "Copying report files to H:\CustomerDeployments\$customer\ReportDeployments"
 
# Copy report files to customer deployment directory

if ((Test-Path $reportDestPath))
{
    Remove-Item $reportDestPath -Recurse -Force
}


Copy-Item $reportSrcPath $reportDestPath -Recurse
#>


#we don't deploy application project for R4
# Update project/data source files and then deploy

<#
echo "Updating Application defaultDS.rds"
$reportFilePath = $reportDestPath + "\Application\defaultDS.rds"
$reportFile = (Get-Content $reportFilePath) -as [Xml]
$reportFile.SelectSingleNode("//RptDataSource/ConnectionProperties/ConnectString").InnerText = $connectionString
$reportFile.Save($reportFilePath) 


echo "Updating Application Project File"
$targetReportFolder = $customer + "/Application"
$reportFilePath = Join-Path -Path $reportDestPath -ChildPath "\Application\Application Reports.rptproj"
$reportFile = (Get-Content $reportFilePath) -as [Xml]
$reportFile.SelectSingleNode("//Configurations/Configuration[Name='Debug']/Options/TargetServerURL").InnerText = $targetServerUrl
$reportFile.SelectSingleNode("//Configurations/Configuration[Name='Debug']/Options/TargetServerVersion").InnerText = $targetServerVersion
$reportFile.SelectSingleNode("//Configurations/Configuration[Name='Debug']/Options/TargetFolder").InnerText = $targetReportFolder
$reportFile.SelectSingleNode("//Configurations/Configuration[Name='Debug']/Options/TargetDataSourceFolder").InnerText = $targetDataSourceFolder

if(!$reportFile.SelectSingleNode("//Configurations/Configuration[Name='Debug']/Options/OverwriteDataSources"))
{
    $newChildElement = $reportFile.CreateElement("OverwriteDataSources")
    $newChildElement.InnerText = "true" 
    $reportFile.SelectSingleNode("//Configurations/Configuration[Name='Debug']/Options").AppendChild($newChildElement)
}
if(!$reportFile.SelectSingleNode("//Configurations/Configuration[Name='Debug']/Options/TargetDatasetFolder"))
{
    $newChildElement = $reportFile.CreateElement("TargetDatasetFolder")
    $newChildElement.InnerText = ""
    $reportFile.SelectSingleNode("//Configurations/Configuration[Name='Debug']/Options").AppendChild($newChildElement)
}

$reportFile.Save($reportFilePath)

echo "Deploying the Application report project"
$argumentList = "-path `"$reportFilePath`" -configuration Debug -customerID $customer -customerPassword $customerPassword -verbose"
$scriptPath = Join-Path -Path $PSScriptRoot -ChildPath "Deploy-SSRSProject.ps1"
Invoke-Expression "$scriptPath $argumentList"
#>



#echo "Updating BPT defaultDS.rds"
echo "Updating BMRAMDS.rds"
#$reportFilePath = $reportDestPath + "\BPTemplate\defaultDS.rds"
$reportFilePath = $reportDestPath + "\R4BPTemplate\BMRAMDS.rds"
$targetDatasetFolder = $customer + "/R4BPTemplate/Datasets" 

$reportFile = (Get-Content $reportFilePath) -as [Xml]
$reportFile.SelectSingleNode("//RptDataSource/ConnectionProperties/ConnectString").InnerText = $connectionString
$reportFile.Save($reportFilePath)


echo "Updating BPT Project File"
$targetReportFolder = $customer + "/R4BPTemplate"
$targetReportPartFolder = $customer + "/R4BPTemplate/Report Parts"
$reportFilePath = Join-Path -Path $reportDestPath -ChildPath "\R4BPTemplate\R4BPTemplate.rptproj"
$reportFile = (Get-Content $reportFilePath) -as [Xml] 
#$reportFile.SelectSingleNode("//Configurations/Configuration[Name='Debug']/Options/TargetServerURL").InnerText = $targetServerUrl
$reportfile.project.propertygroup[0].TargetServerURL = $targetServerUrl

#$reportFile.SelectSingleNode("//Project/PropertyGroup/TargetServerURL").InnerText = $targetServerUrl

#$reportFile.SelectSingleNode("//Configurations/Configuration[Name='Debug']/Options/TargetServerVersion").InnerText = $targetServerVersion
$reportfile.project.propertygroup[0].TargetServerVersion = $targetServerVersion
#$reportFile.SelectSingleNode("//Configurations/Configuration[Name='Debug']/Options/TargetFolder").InnerText = $targetReportFolder
$reportfile.project.propertygroup[0].TargetReportFolder = $targetReportFolder
#$reportFile.SelectSingleNode("//Configurations/Configuration[Name='Debug']/Options/TargetDataSourceFolder").InnerText = $targetDataSourceFolder
$reportfile.project.propertygroup[0].TargetDataSourceFolder = $targetDataSourceFolder
$reportfile.project.propertygroup[0].TargetReportPartFolder = $targetReportPartFolder

<#
if(!$reportFile.SelectSingleNode("//Configurations/Configuration[Name='Debug']/Options/OverwriteDataSources"))
{
    $newChildElement = $reportFile.CreateElement("OverwriteDataSources")
    $newChildElement.InnerText = "true"
    $reportFile.SelectSingleNode("//Configurations/Configuration[Name='Debug']/Options").AppendChild($newChildElement)
}
#>

if(!$reportfile.project.propertygroup[0].OverwriteDataSources)
{
    $newChildElement = $reportFile.CreateElement("OverwriteDataSources")
    $newChildElement.InnerText = "true"
    $reportfile.project.propertygroup[0].AppendChild($newChildElement)
}

<#
if(!$reportFile.SelectSingleNode("//Configurations/Configuration[Name='Debug']/Options/TargetDatasetFolder"))
{
    $newChildElement = $reportFile.CreateElement("TargetDatasetFolder")
    $newChildElement.InnerText = ""
    $reportFile.SelectSingleNode("//Configurations/Configuration[Name='Debug']/Options").AppendChild($newChildElement)
}
#>
if(!$reportfile.project.propertygroup[0].TargetDatasetFolder)
{
    $newChildElement = $reportFile.CreateElement("TargetDatasetFolder")
    $newChildElement.InnerText = ""
    $reportfile.project.propertygroup[0].TargetDatasetFolder.AppendChild($newChildElement)
}

#$reportFile.SelectSingleNode("//Configurations/Configuration[Name='Debug']/Options/TargetDatasetFolder").InnerText = $targetDatasetFolder
$reportfile.project.propertygroup[0].TargetDatasetFolder = $targetDatasetFolder

#adding to clear out report parts
<#
if(!$reportfile.project.propertygroup[0].TargetReportPartFolder)
{
    $newChildElement = $reportFile.CreateElement("TargetReportPartFolder")
    $newChildElement.InnerText = ""
    $reportfile.project.propertygroup[0].TargetReportPartFolder.AppendChild($newChildElement)
}

$reportfile.project.propertygroup[0].TargetReportPartFolder = ""
#>

if(!$reportfile.project.propertygroup[0].TargetReportPartFolder)
{
    $newChildElement = $reportFile.CreateElement("TargetReportPartFolder")
    $newChildElement.InnerText = ""
    $reportfile.project.propertygroup[0].TargetReportPartFolder.AppendChild($newChildElement)
}

$reportfile.project.propertygroup[0].TargetReportPartFolder = $targetReportPartFolder



$reportFile.Save($reportFilePath)

<#
#get Datasource
$includeDataSources = $reportFile.Project.ItemGroup.Datasource.Include
$includeDataSources | Out-File "c:\deployreportprojectconfig.txt" -Append
#get Datasets
$includeDatasets = $reportFile.project.itemgroup.Dataset.Include
$includeDatasets | Out-File "c:\deployreportprojectconfig.txt" -Append
#get images
$includeImages = $reportFile.project.itemgroup.Report
$includeImages2 = $includeImages | where-object {$_.Include -notlike "*.rdl"}
$includeImages2 | Out-File "c:\deployreportprojectconfig.txt" -Append
#get Reports
$includeReports = $reportFile.project.itemgroup.Report.Include
$includeReports | Out-File "c:\deployreportprojectconfig.txt" -Append

#>


#  Only deploy BPT reports for the BPT deployment mode
if ( $deploymentMode -eq "BPT") 
{
echo "Deploying the BPT report project"
$argumentList = "-path $reportFilePath -configuration Debug -customerID $customer -customerPassword '$($customerPassword)' -dataSourceUserName $dataSourceUserName -verbose"
$scriptPath = Join-Path -Path $PSScriptRoot -ChildPath "Deploy-SSRSProjectForR4.ps1"
Invoke-Expression "$scriptPath $argumentList"
}

if ( $deploymentMode -eq "NO_BPT") 
{
echo "Deploying the NO_BPT report project but project doesn't exist yet"
}

#we don't deploy templates in R4
<#
echo "Updating Template defaultDS.rds"
$reportFilePath = $reportDestPath + "\Templates\defaultDS.rds"
$reportFile = (Get-Content $reportFilePath) -as [Xml]
$reportFile.SelectSingleNode("//RptDataSource/ConnectionProperties/ConnectString").InnerText = $connectionString
$reportFile.Save($reportFilePath) 


echo "Updating Template Project File"
$targetReportFolder = $customer + "/BMRAMReports"
$reportFilePath = Join-Path -Path $reportDestPath -ChildPath "\Templates\ReportDeploy.rptproj"
$reportFile = (Get-Content $reportFilePath) -as [Xml]
$reportFile.SelectSingleNode("//Configurations/Configuration[Name='Debug']/Options/TargetServerURL").InnerText = $targetServerUrl
$reportFile.SelectSingleNode("//Configurations/Configuration[Name='Debug']/Options/TargetServerVersion").InnerText = $targetServerVersion
$reportFile.SelectSingleNode("//Configurations/Configuration[Name='Debug']/Options/TargetFolder").InnerText = $targetReportFolder
$reportFile.SelectSingleNode("//Configurations/Configuration[Name='Debug']/Options/TargetDataSourceFolder").InnerText = $targetDataSourceFolder

if(!$reportFile.SelectSingleNode("//Configurations/Configuration[Name='Debug']/Options/OverwriteDataSources"))
{
    $newChildElement = $reportFile.CreateElement("OverwriteDataSources")
    $newChildElement.InnerText = "true"
    $reportFile.SelectSingleNode("//Configurations/Configuration[Name='Debug']/Options").AppendChild($newChildElement)
}
if(!$reportFile.SelectSingleNode("//Configurations/Configuration[Name='Debug']/Options/TargetDatasetFolder"))
{
    $newChildElement = $reportFile.CreateElement("TargetDatasetFolder")
    $newChildElement.InnerText = ""
    $reportFile.SelectSingleNode("//Configurations/Configuration[Name='Debug']/Options").AppendChild($newChildElement)
}

$reportFile.Save($reportFilePath)


if ($deployTemplateReports)
{

    echo "Deploying the Template report project"
    $argumentList = "-path `"$reportFilePath`" -configuration Debug -customerID $customer -customerPassword $customerPassword -verbose"
    $scriptPath = Join-Path -Path $PSScriptRoot -ChildPath "Deploy-SSRSProject.ps1"
    Invoke-Expression "$scriptPath $argumentList"

}
#>

echo "Running Granting Report Folder Permissions to set Browser Role for bmqr\$dataSourceUserName"
./GrantReportFolderPermissionsForR4.ps1 -customerID $customer -listenerName $listenerName -dataSourceUserName $dataSourceUserName
