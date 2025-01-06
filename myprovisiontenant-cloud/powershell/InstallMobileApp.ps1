param
(
    [Parameter(Mandatory=$True,Position=1)]
        [System.Data.SqlClient.SqlConnection]$dbConnection,
    [Parameter(Mandatory=$false,Position=2)][string]$API_URL,
    [Parameter(Mandatory=$false,Position=3)][string]$AUDIENCE    
)

Set-Location $PSScriptRoot

$logDate = Get-Date -UFormat "%d%b%Y_%T" | ForEach-Object  { $_ -replace ":", "_" }

#$dbConnection = $applicationDatabaseConnection 
$customerDB = $dbConnection.Database 
$customerID = $customerDB.replace('_RAMDB','')
$logfile = "installMobileApp_" + $customerID + "_" + $logDate + ".log"
$path = "H:\CustomerDeployments\$customerID\$logfile"

Start-Transcript -path $path

$date = Get-Date

try {
    Set-Location $PSScriptRoot
    
    $query = "
        DELETE FROM BMRAM.tblInstalledModuleRegistry WHERE ModuleID = 'MOBILEAPP';
        DELETE FROM BMRAM.tblInstalledModules WHERE ModID = 'MOBILEAPP';
        INSERT INTO BMRAM.tblInstalledModules VALUES ('MOBILEAPP', 'RAM Mobile Application', 'MOBILE-1.0.0.0', '');
        INSERT INTO BMRAM.tblInstalledModuleRegistry VALUES ('MOBILEAPP', 'API_URL', '$API_URL');
        INSERT INTO BMRAM.tblInstalledModuleRegistry VALUES ('MOBILEAPP', 'AUDIENCE', '$AUDIENCE');
    "

    $command = $dbConnection.CreateCommand()
    $command.CommandText = $query

    $command.ExecuteNonQuery()

    "***********************************************************************************************************************************************************************************" 
    "Mobile App Module was successfully installed! $date" 
    "***********************************************************************************************************************************************************************************" 
}
catch {
    Set-Location $PSScriptRoot
     
    Write-Output " "
    Write-Output "Errors encountered.  Module not installed." 
    Write-Output $($PSItem.ToString()) -Verbose 
}


Stop-Transcript 

Set-Location $PSScriptRoot
