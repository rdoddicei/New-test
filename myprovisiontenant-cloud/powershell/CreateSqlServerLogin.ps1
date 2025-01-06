[CmdletBinding()]
Param(
[Parameter(Mandatory=$false,Position=1)]
    [System.Data.SqlClient.SqlConnection]$databaseConnection, #System.Data.SqlClient.SqlConnection object. if passed, $applicationDatabaseConnection.State should be Open, pointing to master. otherwise, new connection is created below
[Parameter(Mandatory=$false,Position=2)]
    [string]$databaseServer,
[Parameter(Mandatory=$false,Position=3)]
    [string]$databaseName="master",
[Parameter(Mandatory=$false,Position=4)]
    [string]$managementDatabaseAccountLogin,
[Parameter(Mandatory=$false,Position=5)]
    [string]$managementDatabaseAccountLoginPassword,
[Parameter(Mandatory=$false,Position=6)]
    [string]$managementDatabaseAccountLoginDomain,
[Parameter(Mandatory=$true,Position=7)]
    [string]$databaseSqlLoginName,
[Parameter(Mandatory=$false,Position=8)]
    [string]$databaseSqlLoginPassword,
[Parameter(Mandatory=$false,Position=9)]
    [bool]$disableLogin = $false,
[Parameter(Mandatory=$false,Position=10)]
    [bool]$continueOnError = $true
)

Add-Type -AssemblyName System.web
Set-Location $PSScriptRoot;
cd $PSScriptRoot;
Import-Module -Name .\exec-query.ps1 -Force; #force reloads if it's already loaded
Import-Module -Name .\New-SqlConnection.ps1 -Force; #force reloads if it's already loaded

$closeConnection = $false;  #indicates whether this connection originated here and should be closed at the end of the script. eg, it should NOT
							#be closed if this is being run from MyExecDBScripts, in which case the same connection will continue to be used afterward

if (!$databaseConnection) #if no $databaseConnection was passed (e.g. if this script is being run directly), initialize it
{
	$databaseConnection = New-SqlConnection -databaseServer $databaseServer `
											-databaseAccountLogin $managementDatabaseAccountLogin `
											-databaseAccountLoginPassword $managementDatabaseAccountLoginPassword `
											-databaseAccountLoginDomain $managementDatabaseAccountLoginDomain `
											-database $databaseName;
    $closeConnection = $true;
}

if([string]::IsNullOrEmpty($databaseSqlLoginPassword))
{
	$databaseSqlLoginPassword= [System.Web.Security.Membership]::GeneratePassword(30,10)
	#Write-Output ("##vso[task.setvariable variable=databaseSqlLoginPassword;]$databaseSqlLoginPassword");
	#Write-Host $databaseSqlLoginPassword;
}

$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine("USE Master;")
[void]$sb.AppendLine("IF NOT EXISTS (SELECT * FROM sys.sql_logins WHERE Name = '$($databaseSqlLoginName)')")
[void]$sb.AppendLine("BEGIN")
[void]$sb.AppendLine("	CREATE LOGIN $($databaseSqlLoginName) WITH PASSWORD = '$($databaseSqlLoginPassword)',")
[void]$sb.AppendLine("		CHECK_POLICY = OFF;")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("	ALTER LOGIN $($databaseSqlLoginName) WITH CHECK_EXPIRATION = OFF;")
if($disableLogin)
{
	[void]$sb.AppendLine("	ALTER LOGIN $($databaseSqlLoginName) DISABLE;")
}
[void]$sb.Append("END;")
$sql = $sb.ToString()


#Write-Output $sql;

exec-query -databaseConnection $databaseConnection -sql $sql -continueOnError $continueOnError

if ($closeConnection)
{
    $databaseConnection.Close();
}

## The password as it is now:
#$PW
 
## Converted to SecureString
#$SecurePass = $PW | ConvertTo-SecureString -AsPlainText -Force
 
## The SecureString object
#$SecurePass