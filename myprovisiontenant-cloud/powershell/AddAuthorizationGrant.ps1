[CmdletBinding()]
Param(
[Parameter(Mandatory=$True,Position=1)]
    [object]$databaseConnection,
[Parameter(Mandatory=$True,Position=2)]
    [string]$authorizationGrantID,
[Parameter(Mandatory=$True,Position=3)]
    [string]$authorizationGrantName,
[Parameter(Mandatory=$True,Position=4)]
    [string]$expirationDate,
[Parameter(Mandatory=$True,Position=5)]
    [string]$comments,
[Parameter(Mandatory=$False,Position=6)]
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

DECLARE @authorizationGrantName NVARCHAR(255) = '$authorizationGrantName'
DECLARE @authorizationGrantID NVARCHAR(255) = '$authorizationGrantID'

DECLARE @expirationDate NVARCHAR(255) = '$expirationDate'
DECLARE @comments NVARCHAR(255) = '$comments'

DECLARE @authorizationGrantRecordID UNIQUEIDENTIFIER = NEWID()
DECLARE @ischanged UNIQUEIDENTIFIER = NEWID()

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
	<parm id=""recordid"">'+ CAST(@authorizationGrantRecordID as nvarchar(36))+'</parm>
	</parms>
</root>'
EXEC BMRAM.setParm 'recordid', @authorizationGrantRecordID;
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
		<parm id=""recordid"">'+ cast(@authorizationGrantRecordID as nvarchar(36))+'</parm>
		<parm id=""newischanged"">'+cast(@ischanged as nvarchar(36))+'</parm>
		<parm id=""scopeid"">'+cast( @scopeID as nvarchar(36))+'</parm>
		<parm id=""method"">PUT_ENTITY_RECORD</parm>
		<parm id=""publisherid"">' + CAST(@publisherID AS NVARCHAR(36)) + '</parm>
		<parm id=""action"">ATADD</parm>
		<parm id=""setname"">SYSTEM</parm>
		<parm id=""entityname"">AUTHORIZATIONGRANT</parm>' AS XML)
		FOR XML PATH('parms'), TYPE
	),
	(
		SELECT  
		(
			SELECT 
			@authorizationGrantRecordID 'recordid',
			'AUTHORIZATIONGRANT' 'entityname',
			'ATADD' 'action',
			'SYSTEM' 'setname',
			(
				SELECT
					(
					SELECT  'ID' 'attributename',
							@authorizationGrantID 'value',
							@authorizationGrantID 'text'
					FOR XML PATH('field'), TYPE
					),
					(
					SELECT  'Name' 'attributename',
							@authorizationGrantName 'value',
							@authorizationGrantName 'text'
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
					),
					(
					SELECT  'expirationdate' 'attributename',
							@expirationDate 'value',
							@expirationDate 'text'
					FOR XML PATH('field'), TYPE
					),
					(
					SELECT  'comments' 'attributename',
							@comments 'value',
							@comments 'text'
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

