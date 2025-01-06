param
(
    [Parameter(Mandatory=$true, Position=1)][string]$Server,
    [Parameter(Mandatory=$true, Position=2)][string]$DBName,
    [Parameter(Mandatory=$false,Position=3)][string]$DBUserId,
    [Parameter(Mandatory=$false,Position=4)][string]$DBPassword,
    [Parameter(Mandatory=$false,Position=5)][bool]$continueOnError=$false,
    [Parameter(Mandatory=$false,Position=6)][string]$landingDatabaseName="Landing",
    [Parameter(Mandatory=$False,Position=7)][string]$securablesSpreadsheet = "DatabaseObjectPermissions.csv",
    [Parameter(Mandatory=$False,Position=8)][string]$rolesSpreadsheet = "DatabaseRoleMemberships.csv",
    [Parameter(Mandatory=$False,Position=9)][string]$spreadsheetPath = ".\"

)

Set-Location $PSScriptRoot
Import-Module -Name .\exec-sqlfile.ps1 -Force #force reloads if it's already loaded
Import-Module -Name .\exec-query.ps1 -Force #force reloads if it's already loaded

$logDate = Get-Date -UFormat "%d%b%Y_%T" | ForEach-Object  { $_ -replace ":", "_" }
$customerID = $DBName.replace('_RAMDB','')
$logfile = "installGraphQL_" + $customerID + "_" + $logDate + ".log"
$path = "H:\CustomerDeployments\$customerID\$logfile"



Start-Transcript -path $path

$date = Get-Date


$databaseConnection = New-Object System.Data.SqlClient.SqlConnection


"***********************************************************************************************************************************************************************************" 
    
"Installing GraphQL Module $date" 
    
"***********************************************************************************************************************************************************************************" 

$databaseConnection = .\GetDbConnection  -TargetConnection $databaseConnection `
                   -TargetDbServer $Server `
                   -TargetDbName $DBName `
                   -TargetDbUserId $DBUserId `
                   -TargetDbPassword $DBPassword `
                   -continueOnError $continueOnError
 

try
    {
    
        $dbfolder = (Get-Item $PSScriptRoot).Parent.FullName
    
        Set-Location $dbfolder/Scripts

        exec-sqlfile -filePath ./DropAllViews.sql -databaseConnection $databaseConnection -continueOnError $continueOnError 
    
        exec-sqlfile -filePath .\CreateSchema.sql -databaseConnection $databaseConnection -continueOnError $continueOnError 

        Set-Location $dbfolder/Schema
        exec-sqlfile -filePath .\WebAPIRequestLog.sql -databaseConnection $databaseConnection -continueOnError $continueOnError
        exec-sqlfile -filePath ./GraphQLEntities.sql -databaseConnection $databaseConnection -continueOnError $continueOnError  
        exec-sqlfile -filePath ./GraphQLTypes.sql -databaseConnection $databaseConnection -continueOnError $continueOnError  
        exec-sqlfile -filePath ./GraphQLIntrospectionTypes.sql -databaseConnection $databaseConnection -continueOnError $continueOnError  
        exec-sqlfile -filePath ./GraphQLInputObjectTypes.sql -databaseConnection $databaseConnection -continueOnError $continueOnError 
        exec-sqlfile -filePath ./GraphQLInputObjectTypeFields.sql -databaseConnection $databaseConnection -continueOnError $continueOnError  
        exec-sqlfile -filePath ./GraphQLFieldPropOverrides.sql -databaseConnection $databaseConnection -continueOnError $continueOnError  
        exec-sqlfile -filePath ./GraphQLMutations.sql -databaseConnection $databaseConnection -continueOnError $continueOnError  
        exec-sqlfile -filePath ./GraphQLStaticTypes.sql -databaseConnection $databaseConnection -continueOnError $continueOnError  
        exec-sqlfile -filePath ./GraphQLStaticFields.sql -databaseConnection $databaseConnection -continueOnError $continueOnError 
	    exec-sqlfile -filePath ./UserDefinedTableTypes.sql -databaseConnection $databaseConnection -continueOnError $continueOnError 
    
        Set-Location $dbfolder/Updates
        exec-sqlfile -filePath ./SchemaUpdates.sql -databaseConnection $databaseConnection -continueOnError $continueOnError
    

        Set-Location $dbfolder/Functions
        exec-sqlfile -filePath ./fn_GraphQLName.sql -databaseConnection $databaseConnection -continueOnError $continueOnError 
    

        Set-Location $dbfolder/Views

    
        exec-sqlfile -filePath ./vwGraphQLQueryableTypes.sql -databaseConnection $databaseConnection -continueOnError $continueOnError  
        exec-sqlfile -filePath ./vwGraphQLQueryType.sql -databaseConnection $databaseConnection -continueOnError $continueOnError 
        exec-sqlfile -filePath ./vwGraphQLTypes.sql -databaseConnection $databaseConnection -continueOnError $continueOnError 
        exec-sqlfile -filePath ./vwGraphQLInputObjects.sql -databaseConnection $databaseConnection -continueOnError $continueOnError 
        exec-sqlfile -filePath ./vwGraphQLMutations.sql -databaseConnection $databaseConnection -continueOnError $continueOnError 
        exec-sqlfile -filePath ./vwGraphQLMutationType.sql -databaseConnection $databaseConnection -continueOnError $continueOnError 
        exec-sqlfile -filePath ./vwGraphQLIntrospectionTypes.sql -databaseConnection $databaseConnection -continueOnError $continueOnError 
        exec-sqlfile -filePath ./vwGraphQLQueryTypeQueries.sql -databaseConnection $databaseConnection -continueOnError $continueOnError 

        exec-sqlfile -filePath ./vwGraphQLQueryableFields.sql -databaseConnection $databaseConnection -continueOnError $continueOnError  
        exec-sqlfile -filePath ./vwGraphQLInputObjectFields.sql -databaseConnection $databaseConnection -continueOnError $continueOnError  
        exec-sqlfile -filePath ./vwGraphQLFields.sql -databaseConnection $databaseConnection -continueOnError $continueOnError 
        exec-sqlfile -filePath ./vwGraphQLFieldArguments.sql -databaseConnection $databaseConnection -continueOnError $continueOnError 
        exec-sqlfile -filePath ./vwGraphQLEmptySet.sql -databaseConnection $databaseConnection -continueOnError $continueOnError 
        exec-sqlfile -filePath ./vwDocumentVersions.sql -databaseConnection $databaseConnection -continueOnError $continueOnError 
    
    

        exec-sqlfile -filePath ./vwGraphQLSchemaRoot.sql -databaseConnection $databaseConnection -continueOnError $continueOnError 
        exec-sqlfile -filePath ./vwGraphQLDirectives.sql -databaseConnection $databaseConnection -continueOnError $continueOnError 
        exec-sqlfile -filePath ./vwGraphQLInterfaces.sql -databaseConnection $databaseConnection -continueOnError $continueOnError 
        exec-sqlfile -filePath ./vwGraphQLSubscriptionType.sql -databaseConnection $databaseConnection -continueOnError $continueOnError 
    
        Set-Location $dbfolder/Procs

        exec-sqlfile -filePath ./BuildGraphQLTypes.sql -databaseConnection $databaseConnection -continueOnError $continueOnError 
        exec-sqlfile -filePath ./ValidateSchema.sql -databaseConnection $databaseConnection -continueOnError $continueOnError 
        exec-sqlfile -filePath ./BuildGraphQLSchema.sql -databaseConnection $databaseConnection -continueOnError $continueOnError 
        exec-sqlfile -filePath ./LogWebAPIRequest.sql -databaseConnection $databaseConnection -continueOnError $continueOnError 
	    exec-sqlfile -filePath ./ExecCustomProc.sql -databaseConnection $databaseConnection -continueOnError $continueOnError 
    
        Set-Location $dbfolder/Data

        exec-sqlfile -filePath ./datGraphQLEntities.sql -databaseConnection $databaseConnection -continueOnError $continueOnError 
        exec-sqlfile -filePath ./datGraphQLIntrospectionTypes.sql -databaseConnection $databaseConnection -continueOnError $continueOnError 
        exec-sqlfile -filePath ./datGraphQLInputObjectTypes.sql -databaseConnection $databaseConnection -continueOnError $continueOnError 
        exec-sqlfile -filePath ./datGraphQLInputObjectTypeFields.sql -databaseConnection $databaseConnection -continueOnError $continueOnError 
        exec-sqlfile -filePath ./datGraphQLFieldPropOverrides.sql -databaseConnection $databaseConnection -continueOnError $continueOnError
        exec-sqlfile -filePath ./datGraphQLMutations.sql -databaseConnection $databaseConnection -continueOnError $continueOnError 
        exec-sqlfile -filePath ./datGraphQLStaticTypes.sql -databaseConnection $databaseConnection -continueOnError $continueOnError 
        exec-sqlfile -filePath ./datGraphQLStaticFields.sql -databaseConnection $databaseConnection -continueOnError $continueOnError 
     
        Set-Location $dbfolder/Tests
        exec-sqlfile -filePath ./CustomQueryTest.sql -databaseConnection $databaseConnection -continueOnError $continueOnError 

        Set-Location $dbfolder/Scripts

        $sql = "SELECT ApplicationUser FROM $landingDatabaseName.bmqr.TenantConnectionDetails WHERE TenantID = BMRAM.registryKeyValue('TenantID')"
        $loginlessUser = (exec-query -databaseConnection $databaseConnection -sql $sql -continueOnError $continueOnError).ApplicationUser

        .\ApplyPermissions.ps1 -databaseConnection $databaseConnection -databaseServer $databaseServer -databaseName $databaseName -securablesSpreadsheet $securablesSpreadsheet -rolesSpreadsheet $rolesSpreadsheet -spreadsheetPath $spreadsheetPath -loginlessUser $loginlessUser -continueOnError $continueOnError;

        Set-Location $dbfolder/Data

        exec-sqlfile -filePath ./datInstalledModules.sql -databaseConnection $databaseConnection -continueOnError $continueOnError  

        Set-Location $dbfolder/Scripts

        # generate the schema for SYSTEM 
        .\GenerateGraphQLSchema.ps1 -configSetName "SYSTEM" -databaseConnection $databaseConnection -applicationDatabaseServer $Server -applicationDatabaseName $DBName -DBUserId $DBUserId -DBPassword $DBPassword -continueOnError $continueOnError


        "***********************************************************************************************************************************************************************************" 
        "WebAPI Module was successfully installed! $date" 
        "***********************************************************************************************************************************************************************************" 
    }
    catch
    {
        Set-Location $PSScriptRoot

        Write-Output " "
        Write-Output "Errors encountered.  Module not installed." 
        Write-Output $($PSItem.ToString()) -Verbose 
    }


Stop-Transcript 
 
Set-Location $dbfolder/scripts



Set-Location $PSScriptRoot
