[CmdletBinding()]
Param(
[Parameter(Mandatory=$True,Position=1)]
    [object]$databaseConnection,
[Parameter(Mandatory=$True,Position=2)]
    [string]$BMQRAuthenticationSourceID,
[Parameter(Mandatory=$True,Position=3)]
    [string]$BMQRPersonnelID,
[Parameter(Mandatory=$False,Position=4)]
    [string]$osSID,
[Parameter(Mandatory=$False,Position=5)]
    [bool]$continueOnError=$false
)

Set-Location $PSScriptRoot
Import-Module -Name .\exec-nonquery.ps1 -Force #force reloads if it's already loaded


#$databaseConnection = New-Object System.Data.SqlClient.SqlConnection
#$databaseConnection.ConnectionString = “Server=$databaseServer;Integrated Security=true;Initial Catalog=master”
#$databaseConnection.Open()


$sql = "
DECLARE @xmlRequest XML,
		@xmlResponse XML,
		@tranid	UNIQUEIDENTIFIER = NEWID(),
		@sessionID UNIQUEIDENTIFIER = NEWID(),
		@transactionDate datetime2 = BMRAM.IsoFormatDateTime(SYSUTCDATETIME()),
		@systemPersonID UNIQUEIDENTIFIER;

DECLARE @authenticationSourceName NVARCHAR(255);
DECLARE @authenticationSourceID NVARCHAR(255) = '$BMQRAuthenticationSourceID'

SELECT @authenticationSourceName = Name FROM SYSTEM.ADMIN_AUTHSOURCES WHERE ID = @authenticationSourceID AND SetName = 'SYSTEM'

DECLARE @personName NVARCHAR(255);
DECLARE @personID NVARCHAR(255) = '$BMQRPersonnelID'

SELECT @authenticationSourceName = Name FROM SYSTEM.RTPERSONNEL WHERE ID = @personID AND SetName = 'SYSTEM';


DECLARE @osSID NVARCHAR(255) = NEWID()

"
if ($osSID)
{
	$sql = $sql + "SET @osSID = '$osSID';
	"
}

$sql = $sql + "

DECLARE @authRecordID UNIQUEIDENTIFIER;
DECLARE @persRecordID UNIQUEIDENTIFIER;
DECLARE @logonRecordID UNIQUEIDENTIFIER = NEWID()
DECLARE @ischanged UNIQUEIDENTIFIER = NEWID()

SELECT @authRecordID = MemberID FROM SYSTEM.ADMIN_AUTHSOURCES WHERE ID = '$BMQRAuthenticationSourceID' AND SetName = 'SYSTEM'
SELECT @persRecordID = MemberID FROM SYSTEM.RTPERSONNEL WHERE ID = '$BMQRPersonnelID'

DECLARE @active UNIQUEIDENTIFIER;

SELECT @active = MemberID
FROM BMRAM.cfgListItems LI
WHERE LI.EntityName = 'STATUS' AND LI.Name = 'Active';


DECLARE @scopeID UNIQUEIDENTIFIER = BMRAM.fn_GetScopeID('SYSTEM')
DECLARE @publisherID UNIQUEIDENTIFIER = BMRAM.fn_GetPublisherIDByName('') 

SELECT @systemPersonID = EB.MemberID
FROM BMRAM.tblEntityBase EB
WHERE EB.EntityName = 'RTPERSONNEL'
AND EB.ID = 'SYSTEM';



SET @xmlRequest = '<root>
	<parms>
	<parm id=""tranid"">' + CAST(@tranid AS NVARCHAR(36)) + '</parm>
	<parm id=""recordid"">'+ CAST(@logonRecordID as nvarchar(36))+'</parm>
	</parms>
</root>'
EXEC BMRAM.setParm 'recordid', @logonRecordID
EXEC BMRAM.setParm 'utctrandate', @transactionDate;

EXEC bmram.requestSystemSession @xmlRequest, @xmlresponse--create session for specific record creation

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
		<parm id=""recordid"">'+ cast(@logonRecordID as nvarchar(36))+'</parm>
		<parm id=""newischanged"">'+cast(@ischanged as nvarchar(36))+'</parm>
		<parm id=""scopeid"">'+cast( @scopeID as nvarchar(36))+'</parm>
		<parm id=""method"">PUT_ENTITY_RECORD</parm>
		<parm id=""publisherid"">' + CAST(@publisherID AS NVARCHAR(36)) + '</parm>
		<parm id=""action"">ATADD</parm>
		<parm id=""setname"">SYSTEM</parm>
		<parm id=""entityname"">ADMIN_LOGONACCOUNT</parm>' AS XML)
		FOR XML PATH('parms'), TYPE
	),
	(
		SELECT  
		(
			SELECT 
			@logonRecordID 'recordid',
			'ADMIN_LOGONACCOUNT' 'entityname',
			'ATADD' 'action',
			'SYSTEM' 'setname',
			(
				SELECT 
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
					),
					(
					SELECT  'authenticationsourceid' 'attributename',
							@authRecordID 'value',
							@authenticationSourceName 'text'
					FOR XML PATH('field'), TYPE
					),
					(
					SELECT  'requestonly' 'attributename',
							'0' 'value',
							'0' 'text'
					FOR XML PATH('field'), TYPE
					),
					(
					SELECT  'logoncount' 'attributename',
							'0' 'value',
							'0' 'text'
					FOR XML PATH('field'), TYPE
					),
					(
					SELECT  'isactive' 'attributename',
							'1' 'value',
							'1' 'text'
					FOR XML PATH('field'), TYPE
					),
					(
					SELECT  'personid' 'attributename',
							@persRecordID 'value',
							@personName 'text'
					FOR XML PATH('field'), TYPE
					),
					(
					SELECT  'ossid' 'attributename',
							@osSID 'value',
							@osSID 'text'
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

EXEC BMRAM.BMQR_RAM @xmlRequest, @xmlResponse output;

EXEC BMRAM.logOffUser @sessionID;
"

$sqlcmd = $databaseConnection.CreateCommand()
$sqlcmd.CommandText = $sql
$sqlcmd.CommandTimeout = 1800

exec-nonquery -sqlcmd $sqlcmd -continueOnError $continueOnError

