function GetAzureSubscription
{[CmdletBinding()]
 <#Check the subscription in which the script is being executed#>
 <#This only works if it's ran on an Azure VM#>
 <#Returns the name of the subscription#>
    $apiVersion = (Invoke-RestMethod -Headers @{"Metadata"="true"} -Method GET -Uri http://169.254.169.254/metadata/versions).apiVersions | Sort-Object -Descending | Select-Object -First 1
    $VMINFO = Invoke-RestMethod -Headers @{"Metadata"="true"} -Method GET -Uri http://169.254.169.254/metadata/instance?api-version=$apiVersion
    $subscriptionID = $VMINFO.compute.subscriptionID
    
    if($subscriptionID -eq "dfd74ffa-d719-41d8-9070-5120174c4988")
    {
        $subscriptionName = "BMQR-BPT-PRODUCTION"
    }
    elseif ($subscriptionID -eq "d9444266-c716-4600-8110-7e715fe54451")
    {
        $subscriptionName = "BMQR-BPT-DEVELOPMENT"
    }
    return $subscriptionName
}
<############################# END OF FUNCTION ###################################>


function RemoveDatabaseFromAG
{[CmdletBinding()]
<#This just removes the database from the cluster's AG and drops the database from the secondary#>
 Param
    (
        [Parameter(Mandatory=$true)]
        [string] $ClusterNamePrefix,
 
        [Parameter(Mandatory=$true)]
        [string] $DatabaseToRemove
    )

    $primarySvr = "$ClusterNamePrefix-sql-0"
    $secondarySvr = "$ClusterNamePrefix-sql-1"
    $ag = "$ClusterNamePrefix-ag1"
    $bmramDB = $DatabaseToRemove

    $sqlcmdtemplate = "IF EXISTS(  select * from sys.availability_databases_cluster agc
			           inner join sys.availability_groups ag on ag.group_id = agc.group_id
			           where agc.database_name = '{0}' and ag.name = '{1}'
		               )  ALTER AVAILABILITY GROUP [{1}] REMOVE DATABASE {0}"

    $sqlcmd = $sqlcmdtemplate -f ($bmramDB, $ag )

    $message =  "Removing $bmramDB Database from Availability Group if it exists" 
    Write-Output $message
    Invoke-Sqlcmd -ServerInstance $primarySvr -Database master -Query $sqlcmd -Verbose 4>&1 
    Start-Sleep -Seconds 10

    $message = "Deleting $bmramDB from secondary if it exists" 
    Write-Output $message
    Invoke-Sqlcmd -ServerInstance $secondarySvr -Database master -Query "IF ( DB_ID('$bmramDB') IS NOT NULL) DROP DATABASE $bmramDB" -Verbose 4>&1 
    Start-Sleep -Seconds 10
}
<############################# END OF FUNCTION ###################################>


function GetCustomerInfoFromBMRAMControl
{[CmdletBinding()]
<#This gets all the info from the central BMRAMControl database for a customer#>
<#returns a data row object#>
    Param
    (
        [Parameter(Mandatory=$true)]
        [string] $customerName,

        [Parameter(Mandatory=$false)]
        [string] $clusterNamePrefix = $null
    )

    
    $subscriptionName = GetAzureSubscription
    
    <#set some variables depending on subscription#>
    if($subscriptionName -eq "BMQR-BPT-DEVELOPMENT")
    {
        $ControlServer = "r4-01-eus-azsqlserver-bmqrdev.database.windows.net"
        $ControlDatabase = "BMRAMControl"
    }
    elseif($subscriptionName -eq "BMQR-BPT-PRODUCTION")
    {
        $ControlServer = "r4-01-eus-azsqlserver-bmqrprod.database.windows.net"
        $ControlDatabase = "BMRAMControl"
    }

     <#log in to the azure sql db and get info about the customer#>
    $access_token = (Get-AzAccessToken -ResourceUrl https://database.windows.net).Token
    $query = "select * from vwCustomerProps where customerID = '$customerName'"

    if ($null -ne $clusterNamePrefix -and $clusterNamePrefix -ne "")
    {
        $query = $query + " and clusterNamePrefix = '$clusterNamePrefix'"
    }

    Write-Verbose $query
    $customerInfo = invoke-sqlcmd -ServerInstance $ControlServer -Database $ControlDatabase -AccessToken $access_token -Query $query
    if ($null -eq $customerInfo -and $null -ne $clusterNamePrefix -and $clusterNamePrefix -ne "")
    {
        Write-verbose -Message "Customer $customerName not found in the database on $clusterNamePrefix.  Setting this to $clusterNamePrefix for migrations" -ErrorAction Stop
        $query = "select * from vwCustomerProps where customerID = '$customerName'"
        $customerInfo = invoke-sqlcmd -ServerInstance $ControlServer -Database $ControlDatabase -AccessToken $access_token -Query $query
        $customerInfo.ClusterNamePrefix = $clusterNamePrefix
    }
    if (($customerInfo).count -gt 1)
    {
        Write-Error -Message "Customer $customerName found with multiple entries in BMRAMControl.   Run function with the correct ClusterNamePrefix" -ErrorAction Stop
    }
    return $customerInfo
}
<############################# END OF FUNCTION ###################################>

function GenerateBackupDatabaseCommand 
{[CmdletBinding()]
<#This function will return 3 objects: #>
<# 1 - command that will backup the database(s) for a customer#>
<# 2 - an array of file names used for the RAMDB backup (this can be used in restore statements)#>
<# 3 - an array of file names used for the DOCS backup (this can be used in restore statements)#>
    Param
    (
        [Parameter(Mandatory=$true)]
        [string] $customerName,
 
        [Parameter(Mandatory=$true)]
        [ValidateSet("FULL","LOG")]
        [String[]] $backupType,

        [Parameter(Mandatory=$false)]
        [bool] $copyOnly = $true,
        
        [Parameter(Mandatory=$false)]
        [string] $ClusterNameOverride = $null 

 
    )

    <#Make sure the parameters are in the correct case#>
    $customerName = $customerName.ToLower()
    $backupType = $backupType.ToUpper()



    $subscriptionName = GetAzureSubscription
    
    <#set some variables depending on subscription#>
    if($subscriptionName -eq "BMQR-BPT-DEVELOPMENT")
    {
        $BackupURLPrefix = "https://sharedwebcontent.blob.core.windows.net"
    }
    elseif($subscriptionName -eq "BMQR-BPT-PRODUCTION")
    {
        $BackupURLPrefix = "https://bmqrdatastorage.blob.core.windows.net"
    }

    <#log in to the azure sql db and get info about the customer#>
    $customerInfo = GetCustomerInfoFromBMRAMControl -customerName $customerName -clusterNamePrefix $ClusterNameOverride
    
    $clusterNamePrefix = $customerInfo.clusternameprefix
    $DBToBackup = $customerInfo.RAMDBName

    Write-Verbose "Found $customerName on $clusternameprefix"

    $backupPrimarySrv = $clusterNamePrefix + "-sql-0"
    $backupSecondarySrv = $clusterNamePrefix + "-sql-1"
    <######################################################################################################
    # determine if the primary server is currently the secondary replica #>
    try
    {
        $SQLInfo = Invoke-SQLCMD -query "SELECT sys.fn_hadr_backup_is_preferred_replica('BMRAMControl') AS 'IsBackupReplica'" -ServerInstance $backupPrimarySrv -Database "master" -ConnectionTimeout 5 -ErrorAction Stop
    }
    catch
    {
        Write-Verbose "$backupPrimarySrv server is unavailable" 
    }

    if($SQLInfo.IsBackupReplica -or !$copyOnly)
    {
        $backupSrv = $backupPrimarySrv
    }
    else
    {
        Write-Verbose "Backup server is: $backupSecondarySrv"
        $backupSrv = $backupSecondarySrv  
    }
    <#got the backup server#>

    <#fix the backup server if the database isn't in the AG yet but only exists on the primary#>
    $dbexists = invoke-sqlcmd -Query "select * from sys.databases where name = '$DBToBackup' and state_desc = 'online'" -ServerInstance $backupSrv -Database "master" -ConnectionTimeout 5 -ErrorAction Stop
    if ($null -eq $dbexists.name -or $dbexists.name -eq "")
    {
        if ($backupSvr -eq $backupPrimarySrv)
        {
            $backupSvr = $backupSecondarySrv
        }
        else
        {
            $backupSrv = $backupPrimarySrv
        }
    }
    Write-Verbose "Backup server is: $backupSrv"

    <#determine the size of the database to decide if multiple backup files are needed#>
    $databaseSize = invoke-sqlcmd -ServerInstance $backupSrv -Database $DBToBackup -Query "select (sum(FILEPROPERTY(name,'SpaceUsed'))*8192.0/(power(1024,3))) as DBSizeInGB from sys.database_files" -ApplicationIntent ReadOnly 
    $databaseSize = $databaseSize.DBSizeInGB

    $backupFiles = 1
    if ($databaseSize -gt 200 -and $backupType -eq "full")
    {
        $backupFiles = 5
    }
    $backupFileFullPath = @()
    <#build the backup file name#>
    $fileSuffix = Get-Date -Format 'yyyy_MM_dd_HHmmss'
    $fileRandSuffix = (get-random -Minimum 1000000 -Maximum 9999999).ToString()
    if ($backupType -eq "FULL") {$backupExtension = ".bak"}
    elseif ($backupType -eq "LOG") {$backupExtension = ".trn"}
    else {Write-Error -Message "The backuptype is invalid." -ErrorAction Stop }
    $backupFileName = $DBToBackup+"`_backup_"+$fileSuffix+"_"+$fileRandSuffix+$backupExtension
		
    if ($backupFiles -gt 1)
    {
        for ($i = 0; $i -lt $backupFiles; $i++)
        {
            $fileRandSuffixmulti = $fileRandSuffix+"_"+$i.ToString()
            $backupFileName = $DBToBackup+"_backup_"+$fileSuffix+"_"+$fileRandSuffixmulti+$backupExtension
            $backupFileFullPath += "'$BackupURLPrefix/$clusterNamePrefix/Backups/$customerName/$DBToBackup/$backupFileName'"
            if($i -lt $backupFiles - 1)
            {
                $backupFileFullPath += ","
            }
        }
    }
    else 
    {
        $backupFileName = $DBToBackup+"_backup_"+$fileSuffix+"_"+$fileRandSuffix+$backupExtension
        $backupFileFullPath += "'$BackupURLPrefix/$clusterNamePrefix/Backups/$customerName/$DBToBackup/$backupFileName'"
    }
    $ramDBFiles = $null
    <#remove the single quotes from the File Names to allow for easier restore processing#>
    $ramDBFiles = $backupFileFullPath.replace("'","")
    
    <#build the backup command for any customer#>
    $backupCommand = "backup-sqldatabase -ServerInstance $backupSrv -Database $DBToBackup -backupFile @($backupFileFullPath) -verbose -MaxTransferSize 4194304 -blocksize 65536"
    if ($backupType -eq "LOG")
    {
        $backupCommand = $backupCommand + " -BackupAction Log"
    }
    elseif ($copyOnly)
    {
        $backupCommand = $backupCommand + " -CopyOnly"
    }


    $DocDBFiles = $null
    <#if the customer is in the R3 group, backup the DocMan database as well#>
    if ($customerInfo.ApplicationGroup -eq "R3")
    {
        $DBToBackup = $customerInfo.DocManDBName
        $backupFileName = $DBToBackup+"`_backup_"+$fileSuffix+"_"+$fileRandSuffix+$backupExtension
    
        $databaseSize = invoke-sqlcmd -ServerInstance $backupSrv -Database $DBToBackup -Query "select (sum(FILEPROPERTY(name,'SpaceUsed'))*8192.0/(power(1024,3))) as DBSizeInGB from sys.database_files" -ApplicationIntent ReadOnly 
        $databaseSize = $databaseSize.DBSizeInGB

        $backupFiles = 1
        if ($databaseSize -gt 200 -and $backupType -eq "full")
        {
            $backupFiles = 5
        }
        $backupFileFullPath = @()
        <#build the backup file name#>
        $fileSuffix = Get-Date -Format 'yyyy_MM_dd_HHmmss'
        $fileRandSuffix = (get-random -Minimum 1000000 -Maximum 9999999).ToString()
        if ($backupType -eq "FULL") {$backupExtension = ".bak"}
        elseif ($backupType -eq "LOG") {$backupExtension = ".trn"}
        else {Write-Error -Message "The backuptype is invalid." -ErrorAction Stop }
        $backupFileName = $DBToBackup+"`_backup_"+$fileSuffix+"_"+$fileRandSuffix+$backupExtension
		
        if ($backupFiles -gt 1)
        {
            for ($i = 0; $i -lt $backupFiles; $i++)
            {
                $fileRandSuffixmulti = $fileRandSuffix+"_"+$i.ToString()
                $backupFileName = $DBToBackup+"_backup_"+$fileSuffix+"_"+$fileRandSuffixmulti+$backupExtension
                $backupFileFullPath += "'$BackupURLPrefix/$clusterNamePrefix/Backups/$customerName/$DBToBackup/$backupFileName'"
                if($i -lt $backupFiles - 1)
                {
                    $backupFileFullPath += ","
                }
            }
        }
        else 
        {
            $backupFileName = $DBToBackup+"_backup_"+$fileSuffix+"_"+$fileRandSuffix+$backupExtension
            $backupFileFullPath += "'$BackupURLPrefix/$clusterNamePrefix/Backups/$customerName/$DBToBackup/$backupFileName'"<# Action when all if and elseif conditions are false #>
        }
        
        $DocDBFiles = $backupFileFullPath.replace("'","")

        $backupCommand = $backupCommand + "; backup-sqldatabase -ServerInstance $backupSrv -Database $DBToBackup -backupFile @($backupFileFullPath) -verbose -MaxTransferSize 4194304 -blocksize 65536"
        
        if ($backupType -eq "LOG")
        {
            $backupCommand = $backupCommand + " -BackupAction Log"
        }
        elseif ($copyOnly)
        {
            $backupCommand = $backupCommand + " -CopyOnly"
        }
    }

    write-verbose "RAMDB Files used in restore $ramDBFiles"
    if (($DocDBFiles).Count -gt 0)
    {
    write-verbose "DOCS Files used in restore $DocDBFiles"
    }

    <#return the backup command string, RAMBackupFiles, and DOCSBackupFiles#>
    return $backupCommand, @($ramDBFiles), @($DocDBFiles)
}
<############################# END OF FUNCTION ###################################>


function ExecuteR4RestoreOnPrimary
{[CmdletBinding()]
<#This will execute the restore on the PRIMARY server for a given customer#>
<#this requires the backup to be placed in the "Restore" folder in the storage account#>
<#exmple path: <storage account>\<clusterNamePrefix>\<customerID>\<databaseName>\Restore\<backup file(s) #>
Param
    (
        [Parameter(Mandatory=$true)]
        [string] $customerName,
        
        [Parameter(Mandatory=$false)]
        [string] $ClusterNameOverride = $null 
    )


    $subscriptionName = GetAzureSubscription


    <#set some variables depending on subscription#>
    if($subscriptionName -eq "BMQR-BPT-DEVELOPMENT")
    {
        $BackupURLPrefix = "https://sharedwebcontent.blob.core.windows.net"
        $backupSourceAccount = "sharedwebcontent"
        
    }
    elseif($subscriptionName -eq "BMQR-BPT-PRODUCTION")
    {
        $BackupURLPrefix = "https://bmqrdatastorage.blob.core.windows.net"
        $backupSourceAccount = "bmqrdatastorage"
    }
    $resourceGroupName = "BMQR"


    <#log in to the azure sql db and get info about the customer#>
    $customerInfo = GetCustomerInfoFromBMRAMControl -customerName $customerName -clusterNamePrefix $ClusterNameOverride

    $clusterNamePrefix = $customerInfo.clusternameprefix
    $DBToRestore = $customerInfo.RAMDBName

    Write-verbose "Found $customerName on $clusternameprefix"


    $restorePrimaryServer = "$clusterNamePrefix-sql-0"

    #find blobs in database's restore folder
    
    $srcStorageKey = Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -Name $backupSOURCEAccount 
    $srcContext = New-AzStorageContext -StorageAccountName $backupSOURCEAccount -StorageAccountKey $srcStorageKey.Value[0]

    $containerName = $clusterNamePrefix

    $backupfileForLabelCheck = Get-AzStorageBlob -Container $ContainerName -Blob * -Context $srcContext | `
            Where-Object{$_.Name -like "Backups/$customerName/$DBToRestore/Restore/*.bak" }

    if (($backupfileForLabelCheck).count -eq 0)
    {
        write-error "No backups found in customer's Restore folder"
        break
    }
    
    $backupFileNameLabelCheck = $backupfileForLabelCheck[0].name            
    $backupFileURLLabelCheck = "$BackupURLPrefix/$containername/$backupFileNameLabelCheck"

    $query = "RESTORE LabelOnly FROM URL = '$backupFileURLLabelCheck'"
    $labelQueryResult = invoke-sqlcmd -ServerInstance $restorePrimaryServer -database master -Query $query 
    $backupfiles =  $labelQueryResult.familyCount

    if (($backupfileForLabelCheck).Count -ne $backupFiles)
    {
        $filesInFolderCount = ($backupfileForLabelCheck).Count
        write-error "Number of backups in folder ($filesInFolderCount) does not match number of files in the backup set ($backupFiles)"
        break
    }

    <#remove the database from the AG and drop the database from the secondary#>
    RemoveDatabaseFromAG $clusterNamePrefix $DBToRestore

    <#add all the files in the Restore folder to the files to restore#>
    $backupFileURLs = @()
    foreach ($backupFile in $backupfileForLabelCheck)
    {
        $backupFileName = $backupFile.name
        $backupFileURL = "$BackupURLPrefix/$containername/$backupFileName"
        $backupFileURLs += $backupFileURL
    }

    <#get the default location for data and log files#>
    $DefaultLocations = invoke-sqlcmd -ServerInstance $restorePrimaryServer -Query "select InstanceDefaultDataPath = serverproperty('InstanceDefaultDataPath'), InstanceDefaultLogPath = serverproperty('InstanceDefaultLogPath')"
    <#get the logical names from the backup set,  this assumes only 1 data file#>
    $LogicalDBFiles = invoke-sqlcmd -ServerInstance $restorePrimaryServer -Query "restore filelistonly from url = '$backupFileURLLabelCheck'"
    $DataFileName = ($LogicalDBFiles | Where-Object {$_.type -eq "D"}).LogicalName
    $LogFileName = ($LogicalDBFiles | Where-Object {$_.type -eq "L"}).LogicalName

    <#generate the "move" commands to get the logical files named correctly#>
    $RelocateObjects = @()
    $NewDataFile = $DefaultLocations.InstanceDefaultDataPath+"$DBToRestore.mdf"
    $RelocateData = New-Object Microsoft.SqlServer.Management.Smo.RelocateFile($DataFileName, $newDataFile )
    $RelocateObjects += $RelocateData
    $NewLogFile = $DefaultLocations.InstanceDefaultLogPath+"$DBToRestore`_log.ldf"
    $RelocateLog = New-Object Microsoft.SqlServer.Management.Smo.RelocateFile($LogFileName, $newLogFile )
    $RelocateObjects += $RelocateLog
    
    Invoke-Sqlcmd -ServerInstance $restorePrimaryServer -Database master -Query "if exists (select 1 from sys.databases where name = '$DBToRestore') ALTER database $DBToRestore set offline with rollback immediate"
    Invoke-Sqlcmd -ServerInstance $restorePrimaryServer -Database master -Query "if exists (select 1 from sys.databases where name = '$DBToRestore') ALTER database $DBToRestore set online"
    [System.Data.SqlClient.SqlConnection]::ClearAllPools()
    <#restore the database with replace if it exists#>
    write-output "Restoring $DbToRestore to $restorePrimaryServer"
    Restore-SqlDatabase -ServerInstance $restorePrimaryServer -Database $DBToRestore -BackupFile @($backupFileURLs) -RelocateFile $RelocateObjects -ReplaceDatabase
    [System.Data.SqlClient.SqlConnection]::ClearAllPools()
    write-output "Restore $DbToRestore to $restorePrimaryServer complete"
    $databaseOwnerAccount = "RamDatabaseOwner"
    <#since this is the primary we can alter the owner after the restore#>
    Invoke-Sqlcmd -ServerInstance $restorePrimaryServer -Database master -Query "ALTER AUTHORIZATION ON DATABASE::$($DBToRestore) TO [$($databaseOwnerAccount)]" -Verbose 4>&1
    <#set the logical names to match the database name#>
    Invoke-Sqlcmd -ServerInstance $restorePrimaryServer -Database master -Query "if not exists ( select * from sys.master_files where name = '$DBToRestore' ) ALTER DATABASE [$DBToRestore]  MODIFY FILE ( NAME = $DataFileName, NEWNAME = $DBToRestore );"
    Invoke-Sqlcmd -ServerInstance $restorePrimaryServer -Database master -Query "if not exists ( select * from sys.master_files where name = '$DBToRestore`_log' ) ALTER DATABASE $DBToRestore MODIFY FILE ( NAME = $LogFileName, NEWNAME = $DBToRestore`_log );"


    $sql = "ALTER DATABASE [$DBToRestore] SET NEW_BROKER WITH ROLLBACK IMMEDIATE; ALTER DATABASE [$DBToRestore] SET ENABLE_BROKER;"
    Invoke-Sqlcmd -ServerInstance $restorePrimaryServer -Database master -Query $sql

    write-output "Setting compat level to 150 if needed"
    $sql = "
    USE master
    IF  (SELECT substring(ProductVersion, 1, CHARINDEX('.', ProductVersion, 1) - 1) Version
        FROM (SELECT cast(SERVERPROPERTY('ProductVersion') as nvarchar(100)) ProductVersion) D) >= 15
    AND (SELECT compatibility_level FROM sys.databases WHERE name = '$DBToRestore') < 150
    BEGIN
    
        ALTER DATABASE [$DBToRestore] SET compatibility_level = 150
    
    END
    "
    Invoke-Sqlcmd -ServerInstance $restorePrimaryServer -Database master -Query $sql

    write-output "Setting PARAMETERIZATION FORCED if needed"
    $sql = "
    USE master
    IF EXISTS	(
			SELECT 1
			FROM sys.databases AS d
			WHERE d.is_parameterization_forced = 0
			AND d.database_id = DB_ID('$DBToRestore')
			)
    BEGIN

	ALTER DATABASE [$DBToRestore] SET PARAMETERIZATION FORCED;
    END
    "
    Invoke-Sqlcmd -ServerInstance $restorePrimaryServer -Database master -Query $sql

    write-output "Setting recovery to FULL"
    Invoke-Sqlcmd -ServerInstance $restorePrimaryServer -Database master -Query "ALTER DATABASE [$DBToRestore] SET RECOVERY FULL"


}
<############################# END OF FUNCTION ###################################>


function ExecuteR4RestoreOnSecondary
{[CmdletBinding()]
<#This will execute the restore on the SECONDARY server for a given customer#>
<#this assumes the database on the primary is online and available#>
<#it takes a backup from the PRIMARY (full and log) and restores to the secondary#>
<#the database will be joined to the AG after execution#>
Param
    (
        [Parameter(Mandatory=$true)]
        [string] $customerName,
        
        [Parameter(Mandatory=$false)]
        [string] $ClusterNameOverride = $null 
    )

    <#log in to the azure sql db and get info about the customer#>
    $customerInfo = GetCustomerInfoFromBMRAMControl -customerName $customerName -clusterNamePrefix $ClusterNameOverride
    $primaryServer = $customerInfo.ClusterNamePrefix + "-sql-0"
    $secondaryServer = $customerInfo.ClusterNamePrefix + "-sql-1"
    $ag = $customerInfo.ClusterNamePrefix + "-ag1"
    $DatabaseName = $customerInfo.RAMDBName


    <#generate and execute the backup from the PRIMARY server#>
    $backupCMD, $ramDBFiles, $DocDBFiles = GenerateBackupDatabaseCommand -customerName $customerName -backupType FULL -copyOnly $false -ClusterNameOverride $ClusterNameOverride
    $ramDBFullBackup = $ramDBFiles
    Invoke-Expression($backupCMD)

    <#generate and execute the backup from the SECONDARY server#>
    $backupCMD, $ramDBFiles, $DocDBFiles = GenerateBackupDatabaseCommand -customerName $customerName -backupType LOG -ClusterNameOverride $ClusterNameOverride
    $ramDBTranBackup = $ramDBFiles
    Invoke-Expression($backupCMD)

    #add RamDatabaseOwner as sysadmin to do the restore
    invoke-sqlcmd -ServerInstance $secondaryServer -query "ALTER SERVER ROLE [sysadmin] ADD MEMBER [RamDatabaseOwner]"

    <#start building the restore statement using the execution context of the RAMDATABASEOWNER to ensure the proper owner#>
    <#the restore statement has to be built since we can't change security context with the powershell cmdlets#>
    $restoreStatement = "EXECUTE AS LOGIN = 'RamDatabaseOwner'; restore database $DatabaseName from "

        foreach ($file in $ramDBFullBackup)
        {
            if ($file -eq ",") {continue}
            $restoreStatement = $restoreStatement + "url = '$file',"
        }

    #remove the last character from the string
    $restoreStatement = $restoreStatement -replace ".$"
    $restoreStatement = $restoreStatement + " with norecovery"

    invoke-sqlcmd -ServerInstance $secondaryServer -query $restoreStatement
    <#do the log restore the easy way,  nothing special needed here#>
    Restore-SqlDatabase -Database $DatabaseName -BackupFile @($ramDBTranBackup) -ServerInstance $secondaryServer -RestoreAction "Log" -ReplaceDatabase -NoRecovery 

    <#add the database to the AG#>
    $pathAGprim = "SQLSERVER:\SQL\" + $primaryServer + "\Default\AvailabilityGroups\" + $ag
    $pathAGsec = "SQLSERVER:\SQL\" + $secondaryServer + "\Default\AvailabilityGroups\" + $ag
    Add-SqlAvailabilityDatabase -Path $pathAGprim -Database $DatabaseName
    Add-SqlAvailabilityDatabase -Path $pathAGsec -Database $DatabaseName

    #remove RamDatabaseOwner as sysadmin 
    invoke-sqlcmd -ServerInstance $secondaryServer -database master -query "ALTER SERVER ROLE [sysadmin] DROP MEMBER [RamDatabaseOwner]"
}
<############################# END OF FUNCTION ###################################>


Export-ModuleMember -Function GenerateBackupDatabaseCommand
Export-ModuleMember -Function ExecuteR4RestoreOnPrimary
Export-ModuleMember -Function ExecuteR4RestoreOnSecondary
Export-ModuleMember -Function RemoveDatabaseFromAG
Export-ModuleMember -Function GetAzureSubscription
Export-ModuleMember -Function GetCustomerInfoFromBMRAMControl