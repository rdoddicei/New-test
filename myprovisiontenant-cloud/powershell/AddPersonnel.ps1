[CmdletBinding()]
Param(
[Parameter(Mandatory=$True,Position=1)]
    [object]$databaseConnection,
[Parameter(Mandatory=$True,Position=2)]
    [string]$BMQRPersonnelID,
[Parameter(Mandatory=$True,Position=3)]
    [string]$BMQRPersonnelName,
[Parameter(Mandatory=$False,Position=4)]
    [string]$BMQRPersonnelFirstName,
[Parameter(Mandatory=$False,Position=5)]
    [string]$BMQRPersonnelLastName,
[Parameter(Mandatory=$False,Position=6)]
    [string]$BMQRPersonnelEmail,
[Parameter(Mandatory=$False,Position=7)]
    [string]$BMQRPersonnelInitialWorkspaceID,
[Parameter(Mandatory=$False,Position=8)]
    [string]$BMQRPersonnelScopeID,
[Parameter(Mandatory=$False,Position=9)]
    [object[]]$groupMemberships,
[Parameter(Mandatory=$False,Position=10)]
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

DECLARE @personName NVARCHAR(255) = '$BMQRPersonnelName'
DECLARE @personID NVARCHAR(255) = '$BMQRPersonnelID'
DECLARE @firstName NVARCHAR(255) = '$BMQRPersonnelFirstName'
DECLARE @lastName NVARCHAR(255) = '$BMQRPersonnelLastName'
DECLARE @email NVARCHAR(255) = '$BMQRPersonnelEmail'
DECLARE @initialWorkspace NVARCHAR(255) = '$BMQRPersonnelinitialWorkspaceID'

DECLARE @ischanged UNIQUEIDENTIFIER = NEWID()
DECLARE @scopeAccessDetailID UNIQUEIDENTIFIER = NEWID()
DECLARE @persRecordID UNIQUEIDENTIFIER = NEWID()
DECLARE @initialWorkspaceRecordID UNIQUEIDENTIFIER;

SELECT @persRecordID = COALESCE(P.MemberID, @persRecordID)
FROM SYSTEM.RTPERSONNEL P
WHERE P.ID = @personID;

SELECT @initialWorkspaceRecordID = MemberID
FROM SYSTEM.WORKSPACE W
WHERE W.SetName = 'SYSTEM'
AND W.ID = @initialWorkspace

DECLARE @active UNIQUEIDENTIFIER;

DECLARE @tmpGroupMembershipsToAdd TABLE
(
	GroupID SYSNAME,
	ScopeID NVARCHAR(255)
)

"

foreach($groupMembership in $groupMemberships)
{
	$sql = $sql + "INSERT INTO @tmpGroupMembershipsToAdd SELECT '" + $groupMembership[0] + "', '" + $groupMembership[1] + "'
	"
}

$sql = $sql + "

SELECT @active = MemberID
FROM BMRAM.cfgListItems LI
WHERE LI.EntityName = 'STATUS' AND LI.Name = 'Active';

DECLARE @scopeID UNIQUEIDENTIFIER = COALESCE(BMRAM.fn_GetScopeID('$BMQRPersonnelScopeID'), BMRAM.fn_GetScopeID('SYSTEM'))
DECLARE @publisherID UNIQUEIDENTIFIER = BMRAM.fn_GetPublisherIDByName('') 

DECLARE @currentGroupID NVARCHAR(255) = '';
DECLARE @currentScopeID NVARCHAR(255) = '';

DECLARE @currentGroupMemberID UNIQUEIDENTIFIER;
DECLARE @currentScopeMemberID UNIQUEIDENTIFIER;
DECLARE @groupMemberDetailID UNIQUEIDENTIFIER;

DECLARE @tzDSTID UNIQUEIDENTIFIER;
DECLARE @tzDSTName NVARCHAR(255);

DECLARE @utcDateTime DATETIME2 = SYSUTCDATETIME();
DECLARE @lclDateTime DATETIME2 = SYSDATETIME();

DECLARE @workflowMemberID UNIQUEIDENTIFIER;
DECLARE @workflowName NVARCHAR(255);

DECLARE @workflowStageMemberID UNIQUEIDENTIFIER;
DECLARE @workflowStageName NVARCHAR(255);

DECLARE @workflowTransitionMemberID UNIQUEIDENTIFIER;
DECLARE @workflowTransitionName NVARCHAR(255);

DECLARE @workflowEsigChainID UNIQUEIDENTIFIER;

DECLARE @esignatureDetails NVARCHAR(MAX);

SELECT @systemPersonID = EB.MemberID
FROM BMRAM.tblEntityBase EB
WHERE EB.EntityName = 'RTPERSONNEL'
AND EB.ID = 'SYSTEM';

SELECT @tzDSTID = BMRAM.fn_GetTZDSTID(@utcDateTime, S.TZID)
FROM SYSTEM.RTSCOPES S
WHERE S.ID = 'SYSTEM';

SELECT @tzDSTName = TZName
FROM SYSTEM.TIMEZONE
WHERE TZID = @tzDSTID

SELECT @workflowMemberID = DW.DefaultWorkflow,
@workflowName = WD.Name,
@workflowStageName = WS.Name,
@workflowStageMemberID = WS.MemberID,
@workflowTransitionMemberID = WT.MemberID,
@workflowTransitionName = WT.Name,
@workflowEsigChainID = WEC.MemberID
FROM SYSTEM.DEFAULTWORKFLOW DW
INNER JOIN BMRAM.cfgEntities E ON DW.AssociatedEntity = E.EntityLookupKey
INNER JOIN BMRAM.wflDefinitions WD ON DW.DefaultWorkflow = WD.MemberID
INNER JOIN BMRAM.wflStages WS ON WD.MemberID = WS.WorkflowID
INNER JOIN SYSTEM.WORKFLOWTRANSITIONS WT ON WS.MemberID = WT.ToWorkflowStageID AND WT.FromWorkflowStageID IS NULL
INNER JOIN BMRAM.wflStageEsigChains WEC ON WS.MemberID = WEC.WorkflowStageID
WHERE E.EntityName = 'RTPERSONNEL'
AND E.SetName = 'SYSTEM'

SELECT @esignatureDetails = '{""Mask"":""0 of 0"",""StageID"":""' + CAST(@workflowStageMemberID AS NVARCHAR(36)) + '"",""Version"":null,""EsigChainID"":""' + CAST(@workflowEsigChainID AS NVARCHAR(36)) + '"",""LastReasonID"":null,""ESignLogEntries"":[]}'


	SET @xmlRequest = '<root>
		<parms>
		<parm id=""tranid"">' + CAST(@tranid AS NVARCHAR(36)) + '</parm>
		<parm id=""recordid"">'+ CAST(@persRecordID as nvarchar(36))+'</parm>
		</parms>
		</root>'
	EXEC BMRAM.setParm 'recordid', @persRecordID
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
			<parm id=""recordid"">'+ cast(@persRecordID as nvarchar(36))+'</parm>
			<parm id=""newischanged"">'+cast(@ischanged as nvarchar(36))+'</parm>
			<parm id=""scopeid"">'+cast( @scopeID as nvarchar(36))+'</parm>
			<parm id=""method"">PUT_ENTITY_RECORD</parm>
			<parm id=""publisherid"">' + CAST(@publisherID AS NVARCHAR(36)) + '</parm>
			<parm id=""action"">ATADD</parm>
			<parm id=""setname"">SYSTEM</parm>
			<parm id=""entityname"">RTPERSONNEL</parm>' AS XML)
			FOR XML PATH('parms'), TYPE
		),
		(
			SELECT  
			(
				SELECT 
				@persRecordID 'recordid',
				'RTPERSONNEL' 'entityname',
				'ATADD' 'action',
				'SYSTEM' 'setname',
				(
					SELECT 
					(
						SELECT  'ID' 'attributename',
							@personID 'value',
							@personID 'text'
						FOR XML PATH('field'), TYPE
					),
					(
						SELECT  'Name' 'attributename',
							@personName 'value',
							@personName 'text'
						FOR XML PATH('field'), TYPE
					),
					(
						SELECT  'FirstName' 'attributename',
							@firstName 'value',
							@firstName 'text'
						FOR XML PATH('field'), TYPE
					),
					(
						SELECT  'LastName' 'attributename',
							@lastName 'value',
							@lastName 'text'
						FOR XML PATH('field'), TYPE
					),
					(
						SELECT  'Email' 'attributename',
							@email 'value',
							@email 'text'
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
						SELECT  'WorkflowID' 'attributename',
							@workflowMemberID 'value',
							@workflowName 'text'
						FOR XML PATH('field'), TYPE
					),
					(
						SELECT  'EsignatureDetails' 'attributename',
							@esignatureDetails 'value',
							@esignatureDetails 'text'
						FOR XML PATH('field'), TYPE
					),
					(
						SELECT  'LastWorkflowTransitionID' 'attributename',
							@workflowTransitionMemberID 'value',
							@workflowTransitionName 'text'
						FOR XML PATH('field'), TYPE
					),
					(
						SELECT  'LastWorkflowTransitionName' 'attributename',
							@workflowTransitionName 'value',
							@workflowTransitionName 'text'
						FOR XML PATH('field'), TYPE
					),
					(
						SELECT  'LastWorkflowTransitionDaylightSavingTimeID' 'attributename',
							@tzDSTID 'value',
							@tzDSTName 'text'
						FOR XML PATH('field'), TYPE
					),
					(
						SELECT  'LastWorkflowTransitionUtcDate' 'attributename',
							@utcDateTime 'value',
							@utcDateTime 'text'
						FOR XML PATH('field'), TYPE
					),
					(
						SELECT  'LastWorkflowTransitionLocalDate' 'attributename',
							@lclDateTime 'value',
							@lclDateTime 'text'
						FOR XML PATH('field'), TYPE
					),
					(
						SELECT  'LastTransitionedBy' 'attributename',
							@systemPersonID 'value',
							'SYSTEM' 'text'
						FOR XML PATH('field'), TYPE
					),
					(
						SELECT  'WorkflowName' 'attributename',
							@workflowName 'value',
							@workflowName 'text'
						FOR XML PATH('field'), TYPE
					),
					(
						SELECT  'WorkflowStageID' 'attributename',
							@workflowStageMemberID 'value',
							@workflowStageName 'text'
						FOR XML PATH('field'), TYPE
					),
					(
						SELECT  'WorkflowStageName' 'attributename',
							@workflowStageName 'value',
							@workflowStageName 'text'
						FOR XML PATH('field'), TYPE
					),
					(
						SELECT  'WorkflowEndState' 'attributename',
							0 'value',
							0 'text'
						FOR XML PATH('field'), TYPE
					),
					(
						SELECT  'WorkflowVersion' 'attributename',
							1 'value',
							1 'text'
						FOR XML PATH('field'), TYPE
					)
					FOR XML PATH('fields'),TYPE
				),
				(
					SELECT  
					(
						SELECT 
						@personID + ' $BMQRPersonnelScopeID' 'recordname',
						'SCOPEACCESS' 'entityname',
						'ATADD' 'action',
						@scopeAccessDetailID 'recordid',
						@persRecordID 'rootrecordid',
						(
							SELECT 
								(
									SELECT  'ParentID' 'attributename',
										@persRecordID 'value',
										@persRecordID 'text'
									FOR XML PATH('field'), TYPE
								),
								(
									SELECT  'ScopeID' 'attributename',
										@scopeID 'value',
										'$BMQRPersonnelScopeID' 'text'
									FOR XML PATH('field'), TYPE
								),
								(
									SELECT  'Name' 'attributename',
										@personID + ' $BMQRPersonnelScopeID' 'value',
										@personID + ' $BMQRPersonnelScopeID' 'text'
									FOR XML PATH('field'), TYPE
								),
								(
									SELECT  'InitialWorkspace' 'attributename',
										@initialWorkspaceRecordID 'value',
										@initialWorkspace 'text'
									FOR XML PATH('field'), TYPE
								),
								(
									SELECT  'IsDefault' 'attributename',
										1 'value',
										1 'text'
									FOR XML PATH('field'), TYPE
								),
								(
									SELECT  'DetailID' 'attributename',
										@scopeAccessDetailID 'value',
										@scopeAccessDetailID 'text'
									FOR XML PATH('field'), TYPE
								),
								(
									SELECT  'EntityName' 'attributename',
										'SCOPEACCESS' 'value',
										'Scope Access' 'text'
									FOR XML PATH('field'), TYPE
								),
								(
									SELECT  'RootMemberID' 'attributename',
										@persRecordID 'value',
										@personName 'text'
									FOR XML PATH('field'), TYPE
								)
							FOR XML PATH('fields'),TYPE
						)
						FOR XML PATH('record'), TYPE
					)
					FOR XML PATH('records'), TYPE
				)
				FOR XML PATH('record'), TYPE
			)
		FOR XML PATH('records'), TYPE
		)
	FOR XML PATH('root'), TYPE
	)

	EXEC BMRAM.BMQR_RAM @xmlRequest, @xmlResponse output

	EXEC BMRAM.logOffUser @sessionID;


WHILE EXISTS (SELECT 1 FROM @tmpGroupMembershipsToAdd WHERE GroupID > @currentGroupID)
BEGIN

	SET @groupMemberDetailID = NEWID()
	SET @tranID = NEWID()

	SELECT TOP 1 @currentGroupID = GM.GroupID,
	@currentScopeID = GM.ScopeID,
	@currentGroupMemberID = G.MemberID,
	@currentScopeMemberID = S.MemberID
	FROM @tmpGroupMembershipsToAdd GM
	INNER JOIN SYSTEM.ADMIN_GROUPS G ON GM.GroupID = G.ID
	INNER JOIN SYSTEM.RTSCOPES S ON GM.ScopeID = S.ID
	INNER JOIN BMRAM.cfgConfigurationSetsScopeMap CSSM ON S.MemberID = CSSM.ScopeID AND CSSM.SetName = G.SetName
	WHERE GM.GroupID > @currentGroupID
	ORDER BY GM.GroupID ASC;

	SET @xmlRequest = '<root>
		<parms>
		<parm id=""tranid"">' + CAST(@tranid AS NVARCHAR(36)) + '</parm>
		<parm id=""recordid"">'+ CAST(@currentGroupMemberID as nvarchar(36))+'</parm>
		</parms>
		</root>'
	EXEC BMRAM.setParm 'recordid', @currentGroupMemberID
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
		<parm id=""recordid"">'+ cast(@currentGroupMemberID as nvarchar(36))+'</parm>
		<parm id=""newischanged"">'+cast(@ischanged as nvarchar(36))+'</parm>
		<parm id=""scopeid"">'+cast( @scopeID as nvarchar(36))+'</parm>
		<parm id=""method"">PUT_ENTITY_RECORD</parm>
		<parm id=""publisherid"">' + CAST(@publisherID AS NVARCHAR(36)) + '</parm>
		<parm id=""action"">ATEDIT</parm>
		<parm id=""setname"">SYSTEM</parm>
		<parm id=""entityname"">ADMIN_GROUPS</parm>' AS XML)
		FOR XML PATH('parms'), TYPE
	),
	(
		SELECT  
		(
			SELECT 
			@currentGroupMemberID 'recordid',
			'ADMIN_GROUPS' 'entityname',
			'ATEDIT' 'action',
			'SYSTEM' 'setname',
			(
				SELECT
					(
							SELECT 
							@groupMemberDetailID 'recordid',
							'RTGROUP_MEMBER' 'entityname',
							@personID + ' ' + @currentGroupID 'recordname',
							@currentGroupMemberID 'rootrecordid',
							'ATADD' 'action',
							'SYSTEM' 'setname',
							(
								SELECT
								(
									SELECT  'Name' 'attributename',
										@personID + ' ' + @currentGroupID 'value',
										@personID + ' ' + @currentGroupID 'text'
									FOR XML PATH('field'), TYPE
								),
								(
									SELECT  'DetailID' 'attributename',
										@groupMemberDetailID 'value',
										@groupMemberDetailID 'text'
									FOR XML PATH('field'), TYPE
								),
								(
									SELECT  'ParentID' 'attributename',
										@currentGroupMemberID 'value',
										@currentGroupID 'text'
									FOR XML PATH('field'), TYPE
								),
								(
									SELECT  'RootMemberID' 'attributename',
										@currentGroupMemberID 'value',
										@currentGroupID 'text'
									FOR XML PATH('field'), TYPE
								),
								(
									SELECT  'ScopeID' 'attributename',
										@currentScopeMemberID 'value',
										@currentScopeID 'text'
									FOR XML PATH('field'), TYPE
								),
								(
									SELECT  'GroupMemberID' 'attributename',
										@persRecordID 'value',
										@personID 'text'
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

