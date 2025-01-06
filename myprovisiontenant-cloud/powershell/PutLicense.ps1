[CmdletBinding()]
Param(
[Parameter(Mandatory=$False,Position=1)]
    [object]$databaseConnection,
[Parameter(Mandatory=$False,Position=2)]
    [string]$databaseServer = "localhost",
[Parameter(Mandatory=$False,Position=3)]
    [string]$databaseName = "RAMDB_R4SR0",
[Parameter(Mandatory=$True,Position=4)]
    [string]$licenseName,
[Parameter(Mandatory=$True,Position=5)]
    [int]$licenseCount,
[Parameter(Mandatory=$False,Position=6)]
    [bool]$isNamedUserModel=$true,
[Parameter(Mandatory=$False,Position=7)]
    [bool]$isConcurrentFallback=$false,
[Parameter(Mandatory=$False,Position=8)]
    [bool]$allowBackgroundSync=$false,
[Parameter(Mandatory=$False,Position=9)]
    [bool]$continueOnError=$false
)

Set-Location $PSScriptRoot
Import-Module -Name .\exec-nonquery.ps1 -Force #force reloads if it's already loaded

if ($databaseConnection -eq $null) #if no $databaseConnection was passed (e.g. if this script is being run directly), initialize it
{

    $databaseConnection = New-Object System.Data.SqlClient.SqlConnection
    $databaseConnection.ConnectionString = “Server=$databaseServer;Integrated Security=true;Initial Catalog=$databaseName”

    $databaseConnection.Open()
    $closeConnection = $true
}


if ($licenseName -ne "RAMCORE" -and $isNamedUserModel -ne $true)
{
	throw "Error: License $licenseName cannot be assigned a concurrent model. Only RAMCORE may use concurrent licenses."
}

Write-Output ($(Get-Date).ToString() + ": Performing put against license: $licenseName");
Write-Output ($(Get-Date).ToString() + ": Number of licenses: $licenseCount");

if ($isNamedUserModel)
{
	Write-Output ($(Get-Date).ToString() + ": License model: Named User");
}
else
{
	Write-Output ($(Get-Date).ToString() + ": License model: Concurrent");
}



$sql = "
DECLARE @xmlRequest XML,
		@xmlResponse XML,
		@tranid	UNIQUEIDENTIFIER = NEWID(),
		@sessionID UNIQUEIDENTIFIER = NEWID(),
		@transactionDate datetime2 = BMRAM.IsoFormatDateTime(SYSUTCDATETIME()),
		@systemPersonID UNIQUEIDENTIFIER;

DECLARE @licenseMemberID UNIQUEIDENTIFIER;
DECLARE @licenseName NVARCHAR(255) = '$licenseName';
DECLARE @licenseCount INT = $licenseCount;
DECLARE @isConcurrentFallback BIT = 0;
DECLARE @allowBackgroundSync BIT = 0;
DECLARE @isNamedUserModel BIT = 0;

DECLARE @action NVARCHAR(100);
DECLARE @ischanged UNIQUEIDENTIFIER = NEWID();

DECLARE @active UNIQUEIDENTIFIER;


"

if ($isConcurrentFallback -eq $true)
{
	$sql = $sql + "SET @isConcurrentFallback = 1;
	"
}

if ($allowBackgroundSync -eq $true)
{
	$sql = $sql + "SET @allowBackgroundSync = 1;
	"
}

if ($isNamedUserModel -eq $true)
{
	$sql = $sql + "SET @isNamedUserModel = 1
	"
}

$sql = $sql + "

IF EXISTS (SELECT TOP 1 1 FROM SYSTEM.ADMIN_LICENSE WHERE ID = '$licenseName')
BEGIN

	SELECT @action = 'ATEDIT';

	SELECT @licenseMemberID = MemberID
	FROM SYSTEM.ADMIN_LICENSE
	WHERE ID = '$licenseName';

END
ELSE
BEGIN

	SELECT @action = 'ATADD';
	SELECT @licenseMemberID = NEWID();

END

SELECT @active = MemberID
FROM BMRAM.cfgListItems LI
WHERE LI.EntityName = 'STATUS' AND LI.Name = 'Active';

DECLARE @scopeID UNIQUEIDENTIFIER = BMRAM.fn_GetScopeID('SYSTEM')
DECLARE @publisherID UNIQUEIDENTIFIER = BMRAM.fn_GetPublisherIDByName('') 



DECLARE @utcDateTime DATETIME2 = SYSUTCDATETIME();
DECLARE @lclDateTime DATETIME2 = SYSDATETIME();


SELECT @systemPersonID = EB.MemberID
FROM BMRAM.tblEntityBase EB
WHERE EB.EntityName = 'RTPERSONNEL'
AND EB.ID = 'SYSTEM';


	SET @xmlRequest = '<root>
		<parms>
		<parm id=""tranid"">' + CAST(@tranid AS NVARCHAR(36)) + '</parm>
		<parm id=""recordid"">'+ CAST(@licenseMemberID as nvarchar(36))+'</parm>
		</parms>
		</root>'
	EXEC BMRAM.setParm 'recordid', @licenseMemberID
	EXEC BMRAM.setParm 'utctrandate', @transactionDate;

	EXEC bmram.requestSystemSession @xmlRequest, @xmlresponse--create session for specific record creation/edit

	SELECT TOP 1 @sessionID = SessionID
	FROM BMRAM.tblSessions S
	WHERE S.PersonID = @systemPersonID
	ORDER BY S.SessionStart DESC;


	SELECT @xmlRequest = 
	(
		SELECT
		(
			SELECT 
			CAST('<parm id=""tranid"">'+cast(@tranid as nvarchar(36))+'</parm>
			<parm id=""sessionid"">'+ cast(@sessionID as nvarchar(36))+'</parm>
			<parm id=""recordid"">'+ cast(@licenseMemberID as nvarchar(36))+'</parm>
			<parm id=""newischanged"">'+cast(@ischanged as nvarchar(36))+'</parm>
			<parm id=""scopeid"">'+cast( @scopeID as nvarchar(36))+'</parm>
			<parm id=""method"">PUT_ENTITY_RECORD</parm>
			<parm id=""publisherid"">' + CAST(@publisherID AS NVARCHAR(36)) + '</parm>
			<parm id=""action"">@action</parm>
			<parm id=""setname"">SYSTEM</parm>
			<parm id=""entityname"">ADMIN_LICENSE</parm>' AS XML)
			FOR XML PATH('parms'), TYPE
		),
		(
			SELECT  
			(
				SELECT 
				@licenseMemberID 'recordid',
				'ADMIN_LICENSE' 'entityname',
				@action 'action',
				'SYSTEM' 'setname',
				(
					SELECT 
					(
						SELECT  'ID' 'attributename',
							@licenseName 'value',
							@licenseName 'text'
						FOR XML PATH('field'), TYPE
					),
					(
						SELECT  'Name' 'attributename',
							@licenseName 'value',
							@licenseName 'text'
						FOR XML PATH('field'), TYPE
					),
					(
						SELECT  'LicenseCount' 'attributename',
							@licenseCount 'value',
							@licenseCount 'text'
						FOR XML PATH('field'), TYPE
					),
					(
						SELECT  'PublisherID' 'attributename',
							@publisherID 'value',
							'System Generated' 'text'
						FOR XML PATH('field'), TYPE
					),
					(
						SELECT  'IsNamedUserModel' 'attributename',
							@isNamedUserModel 'value',
							@isNamedUserModel 'text'
						FOR XML PATH('field'), TYPE
					),
					(
						SELECT  'IsConcurrentFallback' 'attributename',
							@isConcurrentFallback 'value',
							@isConcurrentFallback 'text'
						FOR XML PATH('field'), TYPE
					),
					(
						SELECT  'AllowBackgroundSync' 'attributename',
							@allowBackgroundSync 'value',
							@allowBackgroundSync 'text'
						FOR XML PATH('field'), TYPE
					),
					(
						SELECT  'MemberStatus' 'attributename',
							@active 'value',
							'Active' 'text'
						FOR XML PATH('field'), TYPE
					),
					(
						SELECT  'IsChanged' 'attributename',
							@ischanged 'value',
							@ischanged 'text'
						FOR XML PATH('field'), TYPE
					)
					FOR XML PATH('fields'),TYPE
				)
				FOR XML PATH('record'), TYPE
			)
		FOR XML PATH('records'), TYPE
		)
	FOR XML PATH('root'), TYPE
	)

	EXEC BMRAM.BMQR_RAM @xmlRequest, @xmlResponse output

	EXEC BMRAM.logOffUser @sessionID;



"
$sqlcmd = $databaseConnection.CreateCommand()
$sqlcmd.CommandText = $sql
$sqlcmd.CommandTimeout = 1800

exec-nonquery -sqlcmd $sqlcmd -continueOnError $continueOnError

Write-Output ($(Get-Date).ToString() + ": Finished license put.");
