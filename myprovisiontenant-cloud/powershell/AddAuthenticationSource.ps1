[CmdletBinding()]
Param(
[Parameter(Mandatory=$True,Position=1)]
    [object]$databaseConnection,
[Parameter(Mandatory=$True,Position=2)]
    [string]$BMQRAuthenticationSourceID,
[Parameter(Mandatory=$True,Position=3)]
    [string]$BMQRAuthenticationSourceName,
[Parameter(Mandatory=$True,Position=4)]
    [string]$authenticationType,
[Parameter(Mandatory=$True,Position=5)]
    [bool]$remoteAccessRegistry,
[Parameter(Mandatory=$False,Position=6)]
    [string]$ldapString,
[Parameter(Mandatory=$False,Position=7)]
    [string]$ldapLogon,
[Parameter(Mandatory=$False,Position=8)]
    [string]$baseServer,
[Parameter(Mandatory=$False,Position=9)]
    [string]$domain,
[Parameter(Mandatory=$False,Position=10)]
    [string]$connectionID,
[Parameter(Mandatory=$False,Position=11)]
    [string]$clientID,
[Parameter(Mandatory=$False,Position=12)]
    [object[]]$authenticationPropertyMapsToAdd,
[Parameter(Mandatory=$False,Position=13)]
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

DECLARE @authenticationSourceName NVARCHAR(255) = '$BMQRAuthenticationSourceName'
DECLARE @authenticationSourceID NVARCHAR(255) = '$BMQRAuthenticationSourceID'
DECLARE @authenticationType NVARCHAR(255) = '$authenticationType'
DECLARE @ldapString NVARCHAR(255);
DECLARE @ldapLogon NVARCHAR(255);
DECLARE @baseServer NVARCHAR(255);
DECLARE @domain NVARCHAR(255);
DECLARE @authenticationSourceConnectionID NVARCHAR(255);
DECLARE @authenticationSourceClientID NVARCHAR(255);
DECLARE @activeDirectoryPersonnelMapRecordID UNIQUEIDENTIFIER;

DECLARE @isActive BIT = 1;
"

if ($ldapString)
{
	$sql = $sql + "SET @ldapString = '$ldapString';
	"
}

if ($ldapLogon)
{
	$sql = $sql + "SET @ldapLogon = '$ldapLogon';
	"
}

if ($baseServer)
{
	$sql = $sql + "SET @baseServer = '$baseServer';
	"
}
if ($domain)
{
	$sql = $sql + "SET @domain = '$domain';
	"
}

if ($connectionID)
{
	$sql = $sql + "SET @authenticationSourceConnectionID = '$connectionID';
	"
}


if ($clientID)
{
	$sql = $sql + "SET @authenticationSourceClientID = '$clientID';
	"
}

if ($remoteAccessRegistry -eq $true)
{
	$sql = $sql + "SET @isActive = 0;
	"
}


$sql = $sql + "

DECLARE @authRecordID UNIQUEIDENTIFIER = NEWID()
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


DECLARE @currentAuthenticationPropertyName NVARCHAR(255) = '';
DECLARE @currentAuthenticationPropertyRecordID UNIQUEIDENTIFIER;
DECLARE @currentPersonnelAttributeName SYSNAME;
DECLARE @currentPersonnelAttributeID UNIQUEIDENTIFIER;

DECLARE @tmpADPersonnelMapsToAdd TABLE
(
	AuthenticationPropertyName NVARCHAR(255),
	PersonnelAttributeName SYSNAME
)

"

foreach($authenticationPropertyName in $authenticationPropertyMapsToAdd)
{
	$sql = $sql + "INSERT INTO @tmpADPersonnelMapsToAdd SELECT '" + $authenticationPropertyName[0] + "', '" + $authenticationPropertyName[1] + "'
	"
}

$sql = $sql + "


SET @xmlRequest = '<root>
	<parms>
	<parm id=""tranid"">' + CAST(@tranid AS NVARCHAR(36)) + '</parm>
	<parm id=""recordid"">'+ CAST(@authRecordID as nvarchar(36))+'</parm>
	</parms>
	</root>'
EXEC BMRAM.setParm 'recordid', @authRecordID
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
		<parm id=""recordid"">'+ cast(@authRecordID as nvarchar(36))+'</parm>
		<parm id=""newischanged"">'+cast(@ischanged as nvarchar(36))+'</parm>
		<parm id=""scopeid"">'+cast( @scopeID as nvarchar(36))+'</parm>
		<parm id=""method"">PUT_ENTITY_RECORD</parm>
		<parm id=""publisherid"">' + CAST(@publisherID AS NVARCHAR(36)) + '</parm>
		<parm id=""action"">ATADD</parm>
		<parm id=""setname"">SYSTEM</parm>
		<parm id=""entityname"">ADMIN_AUTHSOURCES</parm>' AS XML)
		FOR XML PATH('parms'), TYPE
	),
	(
		SELECT  
		(
			SELECT 
			@authRecordID 'recordid',
			'ADMIN_AUTHSOURCES' 'entityname',
			'ATADD' 'action',
			'SYSTEM' 'setname',
			(
				SELECT 
					(
					SELECT  'ID' 'attributename',
							@authenticationSourceID 'value',
							@authenticationSourceID 'text'
					FOR XML PATH('field'), TYPE
					),
					(
					SELECT  'Name' 'attributename',
							@authenticationSourceName 'value',
							@authenticationSourceName 'text'
					FOR XML PATH('field'), TYPE
					),
					(
					SELECT  'AuthenticationType' 'attributename',
							@authenticationType 'value',
							@authenticationType 'text'
					FOR XML PATH('field'), TYPE
					),
					(
					SELECT  'LDAPString' 'attributename',
							@ldapString 'value',
							@ldapString 'text'
					FOR XML PATH('field'), TYPE
					),
					(
					SELECT  'LDAPLogon' 'attributename',
							@ldapLogon 'value',
							@ldapLogon 'text'
					FOR XML PATH('field'), TYPE
					),
					(
					SELECT  'BaseServer' 'attributename',
							@baseServer 'value',
							@baseServer 'text'
					FOR XML PATH('field'), TYPE
					),
					(
					SELECT  'Domain' 'attributename',
							@domain 'value',
							@domain 'text'
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
					SELECT  'ConnectionID' 'attributename',
							@authenticationSourceConnectionID 'value',
							@authenticationSourceConnectionID 'text'
					FOR XML PATH('field'), TYPE
					),
					(
					SELECT  'ClientID' 'attributename',
							@authenticationSourceClientID 'value',
							@authenticationSourceClientID 'text'
					FOR XML PATH('field'), TYPE
					),
					(
					SELECT  'IsActive' 'attributename',
							@isActive 'value',
							@isActive 'text'
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

"

if ($remoteAccessRegistry)
{
	$sql = $sql + "EXEC BMRAM.setRegistryKeyValue 'BmqrAuthenticationSource', @authRecordID
	
	"
}

$sql = $sql + "EXEC BMRAM.logOffUser @sessionID;


WHILE EXISTS (SELECT 1 FROM @tmpADPersonnelMapsToAdd WHERE AuthenticationPropertyName > @currentAuthenticationPropertyName)
BEGIN

	SET @activeDirectoryPersonnelMapRecordID = NEWID()
	SET @tranID = NEWID()

	SELECT TOP 1 @currentAuthenticationPropertyName = A.AuthenticationPropertyName,
	@currentAuthenticationPropertyRecordID = P.MemberID,
	@currentPersonnelAttributeName = EA.AttributeName,
	@currentPersonnelAttributeID = EA.AttributeID
	FROM @tmpADPersonnelMapsToAdd A
	INNER JOIN SYSTEM.AUTHPROPERTYMAP P ON A.AuthenticationPropertyName = P.Name
	INNER JOIN BMRAM.cfgEntityAttributes EA ON A.PersonnelAttributeName = EA.AttributeName AND P.SetName = EA.SetName
	WHERE A.AuthenticationPropertyName > @currentAuthenticationPropertyName
	AND P.SetName = 'SYSTEM'
	AND EA.EntityName = 'RTPERSONNEL'
	ORDER BY A.AuthenticationPropertyName ASC;

	SET @xmlRequest = '<root>
		<parms>
		<parm id=""tranid"">' + CAST(@tranid AS NVARCHAR(36)) + '</parm>
		<parm id=""recordid"">'+ CAST(@authRecordID as nvarchar(36))+'</parm>
		</parms>
		</root>'
	EXEC BMRAM.setParm 'recordid', @authRecordID
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
		<parm id=""recordid"">'+ cast(@authRecordID as nvarchar(36))+'</parm>
		<parm id=""newischanged"">'+cast(@ischanged as nvarchar(36))+'</parm>
		<parm id=""scopeid"">'+cast( @scopeID as nvarchar(36))+'</parm>
		<parm id=""method"">PUT_ENTITY_RECORD</parm>
		<parm id=""publisherid"">' + CAST(@publisherID AS NVARCHAR(36)) + '</parm>
		<parm id=""action"">ATEDIT</parm>
		<parm id=""setname"">SYSTEM</parm>
		<parm id=""entityname"">ADMIN_AUTHSOURCE</parm>' AS XML)
		FOR XML PATH('parms'), TYPE
	),
	(
		SELECT  
		(
			SELECT 
			@authRecordID 'recordid',
			'ADMIN_AUTHSOURCES' 'entityname',
			'ATEDIT' 'action',
			'SYSTEM' 'setname',
			(
				SELECT
					(
							SELECT 
							@activeDirectoryPersonnelMapRecordID 'recordid',
							'ACTIVEDIRECTORY_PERSONNEL_MAP' 'entityname',
							@currentAuthenticationPropertyName + ' ' + @authenticationSourceName 'recordname',
							@authRecordID 'rootrecordid',
							'ATADD' 'action',
							'SYSTEM' 'setname',
							(
								SELECT
								(
									SELECT  'Name' 'attributename',
										@currentAuthenticationPropertyName + ' ' + @authenticationSourceName 'value',
										@currentAuthenticationPropertyName + ' ' + @authenticationSourceName 'text'
									FOR XML PATH('field'), TYPE
								),
								(
									SELECT  'DetailID' 'attributename',
										@activeDirectoryPersonnelMapRecordID 'value',
										@activeDirectoryPersonnelMapRecordID 'text'
									FOR XML PATH('field'), TYPE
								),
								(
									SELECT  'ParentID' 'attributename',
										@authRecordID 'value',
										@authenticationSourceName 'text'
									FOR XML PATH('field'), TYPE
								),
								(
									SELECT  'RootMemberID' 'attributename',
										@authRecordID 'value',
										@authenticationSourceName 'text'
									FOR XML PATH('field'), TYPE
								),
								(
									SELECT  'AuthenticationPropertyName' 'attributename',
										@currentAuthenticationPropertyRecordID 'value',
										@currentAuthenticationPropertyName 'text'
									FOR XML PATH('field'), TYPE
								),
								(
									SELECT  'PersonnelAttribute' 'attributename',
										@currentPersonnelAttributeID 'value',
										@currentPersonnelAttributeName 'text'
									FOR XML PATH('field'), TYPE
								)
								FOR XML PATH('fields'), TYPE
							) FOR XML PATH('record'), TYPE
					) FOR XML PATH('records'), TYPE
				) FOR XML PATH('record'), TYPE
			) FOR XML PATH('records'), TYPE
	) FOR XML PATH('root'), TYPE
)

	EXEC BMRAM.BMQR_RAM @xmlRequest, @xmlResponse output


	EXEC BMRAM.logOffUser @sessionID;

END

"
$sqlcmd = $databaseConnection.CreateCommand()
$sqlcmd.CommandText = $sql
$sqlcmd.CommandTimeout = 1800

exec-nonquery -sqlcmd $sqlcmd -continueOnError $continueOnError

