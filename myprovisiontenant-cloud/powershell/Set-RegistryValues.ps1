[CmdletBinding()]
Param(
	[Parameter(Mandatory=$false,Position=1)]
		[System.Data.SqlClient.SqlConnection]$databaseConnection, #System.Data.SqlClient.SqlConnection object. if passed, $databaseConnection.State should be Open, pointing to master. otherwise, new connection is created below
	[Parameter(Mandatory=$false,Position=2)]
		[string]$databaseServer = "localhost",
	[Parameter(Mandatory=$False,Position=3)]
		[string]$databaseName = "RAMDB_R4SR0",
	[Parameter(Mandatory=$false,Position=4)]
		[string]$managementDatabaseAccountLogin,
	[Parameter(Mandatory=$false,Position=5)]
		[string]$managementDatabaseAccountLoginPassword,
	[Parameter(Mandatory=$false,Position=6)]
		[string]$managementDatabaseAccountLoginDomain,
	[Parameter(Mandatory=$false,Position=7)]
		[bool]$systemBuildMode=$false,
	[Parameter(Mandatory=$false,Position=8)]
		[string]$serverUrl,
	[Parameter(Mandatory=$false,Position=9)]
		[string]$recordsPerPage,
	[Parameter(Mandatory=$false,Position=10)]
		[string]$configurationAuditReportId,
	[Parameter(Mandatory=$false,Position=11)]
		[string]$requestOnlyWorkspaceID,
	[Parameter(Mandatory=$false,Position=12)]
		[string]$requestOnlyUserGroupID,
	[Parameter(Mandatory=$false,Position=13)]
		[string]$recordBlockingTimeOut = 60000,
	[Parameter(Mandatory=$false,Position=14)]
		[string]$maximumNestingLevel = 4,
	[Parameter(Mandatory=$false,Position=15)]
		[string]$databaseMailProfile="BMQR",
	[Parameter(Mandatory=$false,Position=16)]
		[string]$systemConfigurationAccess,
	[Parameter(Mandatory=$false,Position=17)]
		[string]$deadlockRetryCount="3",
	[Parameter(Mandatory=$false,Position=18)]
		[string]$deadlockRetryPeriod="10"
	)

cd $PSScriptRoot;

Import-Module -Name .\exec-query.ps1 -Force; #force reloads if it's already loaded
Import-Module -Name .\New-SqlConnection.ps1 -Force; #force reloads if it's already loaded

$ErrorActionPreference="SilentlyContinue"; #quietly end any running transcript (shouldn't be any, but just in case)
Stop-Transcript | out-null;
#$ErrorActionPreference = "Continue"

try { 
     Start-Transcript -path ".\SetRegistryValues.txt";

} catch { 

       stop-transcript;
       Start-Transcript -path ".\SetRegistryValues.txt";
} 
$ErrorActionPreference = "Stop";

#indicates whether these connections originated here and should be closed at the end of the script. eg, it should NOT
#be closed if this is being run from MyExecDBScripts, in which case the same connection will continue to be used afterward
$closeConnection = $false;

if (!$databaseConnection) #if no $databaseConnection was passed (e.g. if this script is being run directly), initialize it
{
	$databaseConnection = New-SqlConnection -databaseServer $databaseServer `
											-databaseAccountLogin $managementDatabaseAccountLogin `
											-databaseAccountLoginPassword $managementDatabaseAccountLoginPassword `
											-databaseAccountLoginDomain $managementDatabaseAccountLoginDomain `
											-database $databaseName;
    $closeConnection = $true;
}

echo ($(Get-Date).ToString() + ": Setting Registry Values");

# Set System Build Mode Value
exec-query -databaseConnection $databaseConnection -sql "EXEC BMRAM.setRegistryKeyValue 'SystemBuildMode', '$([int]$systemBuildMode)'" -continueOnError $continueOnError

if(![string]::IsNullOrEmpty($serverUrl))
{
	#Write-Host "Server Url: $($serverUrl)"
	exec-query -databaseConnection $databaseConnection -sql "EXEC BMRAM.setRegistryKeyValue 'SystemUrl', '$serverUrl'" -continueOnError $continueOnError
}

if(![string]::IsNullOrEmpty($recordsPerPage))
{
	#Write-Host "Records Per Page: $($recordsPerPage)"
	exec-query -databaseConnection $databaseConnection -sql "EXEC BMRAM.setRegistryKeyValue 'RecordsPerPage', '$recordsPerPage'" -continueOnError $continueOnError
}

if(![string]::IsNullOrEmpty($configurationAuditReportId))
{
	#Write-Host "Configuration Audit Report ID: $($configurationAuditReportId)"
	exec-query -databaseConnection $databaseConnection -sql "EXEC BMRAM.setRegistryKeyValue 'ConfigurationAuditReportId', '$configurationAuditReportId'" -continueOnError $continueOnError
}

if(![string]::IsNullOrEmpty($recordBlockingTimeOut))
{
	#Write-Host "Configuration Audit Report ID: $($configurationAuditReportId)"
	exec-query -databaseConnection $databaseConnection -sql "EXEC BMRAM.setRegistryKeyValue 'RecordBlockingTimeOut', '$recordBlockingTimeOut'" -continueOnError $continueOnError
}

if(![string]::IsNullOrEmpty($maximumNestingLevel))
{
	#Write-Host "Configuration Audit Report ID: $($configurationAuditReportId)"
	exec-query -databaseConnection $databaseConnection -sql "EXEC BMRAM.setRegistryKeyValue 'MaximumNestingLevel', '$maximumNestingLevel'" -continueOnError $continueOnError
}

if(![string]::IsNullOrEmpty($databaseMailProfile))
{
	#Write-Host "Configuration Audit Report ID: $($configurationAuditReportId)"
	exec-query -databaseConnection $databaseConnection -sql "EXEC BMRAM.setRegistryKeyValue 'DatabaseMailProfile', '$databaseMailProfile'" -continueOnError $continueOnError
}

if(![string]::IsNullOrEmpty($systemConfigurationAccess))
{
	#Write-Host "System Configuration Visibility: $($systemConfigurationAccess)"
	exec-query -databaseConnection $databaseConnection -sql "EXEC BMRAM.setRegistryKeyValue 'SystemConfigurationAccess', '$($systemConfigurationAccess.replace("'", "''"))'" -continueOnError $continueOnError
}

if(![string]::IsNullOrEmpty($deadlockRetryCount))
{
	#Write-Host "System Configuration Visibility: $($deadlockRetryCount)"
	exec-query -databaseConnection $databaseConnection -sql "EXEC BMRAM.setRegistryKeyValue 'DeadlockRetryCount', '$($deadlockRetryCount.replace("'", "''"))'" -continueOnError $continueOnError
}

if(![string]::IsNullOrEmpty($deadlockRetryPeriod))
{
	#Write-Host "System Configuration Visibility: $($deadlockRetryPeriod)"
	exec-query -databaseConnection $databaseConnection -sql "EXEC BMRAM.setRegistryKeyValue 'DeadlockRetryPeriod', '$($deadlockRetryPeriod.replace("'", "''"))'" -continueOnError $continueOnError
}

$sql = @"
DECLARE @registryKeyValue nvarchar(255);

SET @registryKeyValue = TRY_CAST('$($requestOnlyWorkspaceID)' as uniqueidentifier);

IF @registryKeyValue IS NULL
BEGIN

	SELECT @registryKeyValue = MemberID 
	FROM SYSTEM.WORKSPACE
	WHERE ID = 'RequesterWorkspace';

END;

EXEC BMRAM.setRegistryKeyValue 'RequestOnlyWorkspaceID', @registryKeyValue;
"@;
exec-query -databaseConnection $databaseConnection -sql $sql -continueOnError $continueOnError

$sql = @"
DECLARE @registryKeyValue nvarchar(255);

SET @registryKeyValue = TRY_CAST('$($requestOnlyUserGroupID)' as uniqueidentifier);

IF @registryKeyValue IS NULL
BEGIN

	SELECT @registryKeyValue = MemberID 
	FROM SYSTEM.groups
	WHERE ID = 'bpt_4.WorkRequestCreator';

END;

IF @registryKeyValue IS NOT NULL
BEGIN

	EXEC BMRAM.setRegistryKeyValue 'RequestOnlyUserGroupID', @registryKeyValue;

END;
"@;
exec-query -databaseConnection $databaseConnection -sql $sql -continueOnError $continueOnError

$sql = @"
DECLARE @registryKeyValue nvarchar(255);

SELECT @registryKeyValue = MemberID 
FROM SYSTEM.RTPERSONNEL
WHERE ID = 'System';

IF @registryKeyValue IS NOT NULL
BEGIN

	EXEC BMRAM.setRegistryKeyValue 'SystemAccountPersonId', @registryKeyValue;

END;
"@;
exec-query -databaseConnection $databaseConnection -sql $sql -continueOnError $continueOnError


echo ($(Get-Date).ToString() + ": Registry Values Complete")

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
