[CmdletBinding()]
Param(
[Parameter(Mandatory=$false,Position=1)]
    [System.Data.SqlClient.SqlConnection]$databaseConnection, #System.Data.SqlClient.SqlConnection object. if passed, $applicationDatabaseConnection.State should be Open, pointing to master. otherwise, new connection is created below
[Parameter(Mandatory=$False,Position=2)]
    [string]$databaseServer = "localhost",
[Parameter(Mandatory=$False,Position=3)]
    [string]$databaseName = "RAMDB_R4SR0",
[Parameter(Mandatory=$false,Position=4)]
    [string]$managementDatabaseAccountLogin,
[Parameter(Mandatory=$false,Position=5)]
    [string]$managementDatabaseAccountLoginPassword,
[Parameter(Mandatory=$false,Position=6)]
    [string]$managementDatabaseAccountLoginDomain,
[Parameter(Mandatory=$True,Position=7)]
    [string]$serviceAccountLogin,
[Parameter(Mandatory=$false,Position=8)]
    [string]$serviceAccountLoginDomain,
[Parameter(Mandatory=$True,Position=9)]
    [string]$databaseOwnerAccount,
[Parameter(Mandatory=$false,Position=10)]
    [string]$databaseOwnerAccountDomain,
[Parameter(Mandatory=$True,Position=11)]
    [string]$loginlessUser,
[Parameter(Mandatory=$true,Position=12)]
	[string]$securablesSpreadsheetName,
[Parameter(Mandatory=$false,Position=13)]
	[string]$databaseRoleSpreadsheetName,
[Parameter(Mandatory=$false,Position=14)]
	[string]$securablesSpreadsheetPath,
[Parameter(Mandatory=$False,Position=15)]
	[bool]$continueOnError=$False,
[Parameter(Mandatory=$False,Position=16)]
	[bool]$isDevelopmentEnvironment=$False,
[Parameter(Mandatory=$True,Position=17)]
    [string]$MAINTCounter,
[Parameter(Mandatory=$True,Position=18)]
    [string]$logfileDestination

)
Set-Location $PSScriptRoot;

Import-Module -Name .\exec-query.ps1 -Force; #force reloads if it's already loaded
Import-Module -Name .\exec-sqlfile.ps1 -Force;
Import-Module -Name .\New-SqlConnection.ps1 -Force; #force reloads if it's already loaded

$ErrorActionPreference="SilentlyContinue"; #quietly end any running transcript (shouldn't be any, but just in case)
Stop-Transcript | out-null;
#$ErrorActionPreference = "Continue"
$txtpath = "$logfileDestination\ConfigureSecurity_" + $MAINTCounter + "_" + $databasename + ".txt"

try { 
     Start-Transcript -path $txtpath

} catch { 

       stop-transcript;
       Start-Transcript -path $txtpath
} 
$ErrorActionPreference = "Stop";
Write-Output "****************************************";
Write-Output "Finalizing Tenant Security Configuration";
Write-Output "****************************************"; 

#indicates whether these connections originated here and should be closed at the end of the script. eg, it should NOT
#be closed if this is being run from MyExecDBScripts, in which case the same connection will continue to be used afterward
$closeConnection = $false;

if (!$databaseConnection) #if no $databaseConnection was passed (e.g. if this script is being run directly), initialize it
{
	$databaseConnection = New-Object System.Data.SqlClient.SqlConnection;
	$_databaseConnection = New-Object System.Data.SqlClient.SqlConnection;
	$_databaseConnection = New-SqlConnection -databaseServer $databaseServer `
											-databaseAccountLogin $managementDatabaseAccountLogin `
											-databaseAccountLoginPassword $managementDatabaseAccountLoginPassword `
											-databaseAccountLoginDomain $managementDatabaseAccountLoginDomain `
											-database $databaseName;
	$databaseConnection = $_databaseConnection
    $closeConnection = $true;
}

###########################################Post
#ensure no user for service account in application database to remove existing permissions
#todo Determine if we want to bolster this in case this user owns objects
$sql = "USE $($databaseName);  DROP USER IF EXISTS [$(($serviceAccountLogin))];"
exec-query -databaseConnection $databaseConnection -sql $sql -continueOnError $continueOnError;

# grant Service Account Access to Tenant Application Database
if([string]::IsNullOrEmpty($serviceAccountLoginDomain))
{
	$serviceAccout = $serviceAccountLogin;
}
	else
{
	$serviceAccout =  "$($serviceAccountLoginDomain)\$($serviceAccountLogin)";
}
$sql = "USE $($databaseName); IF DATABASE_PRINCIPAL_ID('$($serviceAccountLogin)') IS NULL CREATE USER [$($serviceAccountLogin)] FOR LOGIN [$($serviceAccout)];";
exec-query -databaseConnection $databaseConnection -sql $sql -continueOnError $continueOnError;

# Create Loginless Database user
$sql = "USE $($databaseName); CREATE USER [$($loginlessUser)] without login;"
exec-query -databaseConnection $databaseConnection -sql $sql -continueOnError $continueOnError;

# Grant Service Account Impersonation Rights
$sql = "USE $($databaseName); GRANT IMPERSONATE on user:: $($loginlessUser) to [$($serviceAccountLogin)];"
exec-query -databaseConnection $databaseConnection -sql $sql -continueOnError $continueOnError; 

#Change database authorization to the least privlige database owner User
if([string]::IsNullOrEmpty($databaseOwnerAccountDomain))
{# No Domain Supplied must be using Sql Login
	$owner = $databaseOwnerAccount;
}
	else
{
	$owner =  "$($databaseOwnerAccountDomain)\$($databaseOwnerAccount)";
}
$sql = "ALTER AUTHORIZATION ON DATABASE::$($databaseName) TO [$($owner)]";
exec-query -databaseConnection $databaseConnection -sql $sql -continueOnError $continueOnError;

# Grant Loginless User rights to needed routines
.\ApplyPermissions.ps1 -databaseConnection $databaseConnection `
					   -securablesSpreadsheet $securablesSpreadsheetName `
					   -rolesSpreadsheet $databaseRoleSpreadsheetName `
					   -spreadsheetPath $securablesSpreadsheetPath `
					   -loginlessUser $loginlessUser `
					   -continueOnError $continueOnError;

try{
	Stop-Transcript;
	}
Catch
	{
	Write-Host "Host Was Not Transcribing";
	}

if ($closeConnection)
{
    $databaseConnection.Close();
}
