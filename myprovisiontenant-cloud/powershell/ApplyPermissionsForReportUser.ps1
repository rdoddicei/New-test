[CmdletBinding()]
Param(
[Parameter(Mandatory=$False,Position=1)]
    [System.Data.SqlClient.SqlConnection]$databaseConnection,
[Parameter(Mandatory=$False,Position=2)]
    [string]$databaseServer = "localhost",
[Parameter(Mandatory=$False,Position=3)]
    [string]$databaseName = "RAMDB_R4SR0",
[Parameter(Mandatory=$False,Position=4)]
    [string]$securablesSpreadsheet = "datPermissions.csv",
[Parameter(Mandatory=$False,Position=5)]
    [string]$rolesSpreadsheet = "datRoleMemberships.csv",
[Parameter(Mandatory=$False,Position=6)]
    [string]$spreadsheetPath = ".\",
[Parameter(Mandatory=$False,Position=7)]
    [string]$reportUserLogin = "Ramuser",
[Parameter(Mandatory=$True,Position=8)]
    [bool]$continueOnError
)

Set-Location $PSScriptRoot
Import-Module -Name .\exec-query.ps1 -Force #force reloads if it's already loaded
#Import-Module -Name .\exec-sqlfile.ps1 -Force

$sql = "";
$_sql = "";




if ($databaseConnection -eq $null) #if no $databaseConnection was passed (e.g. if this script is being run directly), initialize it
{
	$databaseConnection = New-Object System.Data.SqlClient.SqlConnection;
	$databaseConnection.ConnectionString = "Server=$databaseServer;Integrated Security=true;Initial Catalog=$databaseName";
	$databaseConnection.Open();
}


#I don't need roles for the report user, already granted datareader
<#
$roles = Import-Csv -Path $spreadsheetPath\$rolesSpreadsheet;
Write-host("SpreadsheetName: $rolesSpreadsheet");
Write-host("Spreadsheet Path: $spreadsheetPath");

if ($roles.Object.Count -gt 0)
{
	Write-Host "`r`nAdding member to the following roles:`r`n"
}
foreach ($role in $roles)
{
	$_sql = "ALTER ROLE [$($role.'DatabaseRole')] ADD MEMBER [$reportUserLogin];"
	Write-Host $_sql;
	$sql += "$_sql`r`n"
}

#>


$path = [io.path]::combine($spreadsheetPath, $securablesSpreadsheet);
$securables = Import-Csv -Path $path;

if ($securables.Object.Count -gt 0)
{
	Write-Host "`r`nApplying the following permissions:`r`n"
}

$_sql = "";
foreach ($row in $securables)
{
	$permission = $row.'Permission'
	$object = $row.'Object'

	$_sql = "GRANT $permission ON $object TO [$reportUserLogin];"
	Write-Host $_sql;
	$sql += "$_sql`r`n"
}

$_sql = "SELECT Privilege, RoutineSchema, RoutineName 
FROM    (
    SELECT CASE WHEN DATA_TYPE = 'TABLE' THEN 'SELECT' ELSE 'EXEC' END Privilege, ROUTINE_SCHEMA RoutineSchema, ROUTINE_NAME RoutineName
    FROM INFORMATION_SCHEMA.ROUTINES
    WHERE ROUTINE_TYPE = 'FUNCTION'
        
        ) M 
WHERE RoutineName IS NOT NULL";

 

 

$securables = exec-query -databaseConnection $databaseConnection -sql $_sql -continueOnError $continueOnError;

 

foreach($item in $securables) 
{
    $_sql = "GRANT $($item.Privilege) ON [$($item.RoutineSchema)].[$($item.RoutineName)] TO [$($reportUserLogin)];";
    Write-Host $_sql;
    $sql += "$_sql`r`n"
}

exec-query -databaseConnection $databaseConnection -sql $sql -continueOnError $continueOnError;
 

Write-Host "`r`nGranting Access to the following Types:`r`n"