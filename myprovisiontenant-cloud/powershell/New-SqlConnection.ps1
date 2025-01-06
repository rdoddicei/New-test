function New-SqlConnection
{
    [cmdletbinding()]
    [OutputType([System.Data.SqlClient.SQLConnection])]
Param(
     [Parameter(Position=0,
                Mandatory=$true,
                ValueFromPipeline=$true,
                ValueFromPipelineByPropertyName=$true,
                ValueFromRemainingArguments=$false,
                HelpMessage='SQL Server Instance required...' )]
    [Alias( 'Instance', 'Instances', 'ComputerName', 'Server', 'Servers', 'ServerInstance' )]
    [ValidateNotNullOrEmpty()]
        [string[]]$databaseServer,
    [Parameter( Position=1,
                Mandatory=$false,
                ValueFromPipelineByPropertyName=$true,
                ValueFromRemainingArguments=$false)]
        [string]$database="master",
	[Parameter(Mandatory=$false,Position=2)]
		[string]$databaseAccountLogin,
	[Parameter(Mandatory=$false,Position=3)]
		[string]$databaseAccountLoginPassword,
	[Parameter(Mandatory=$false,Position=4)]
		[string]$databaseAccountLoginDomain,
    [Parameter( Position=5,
                    Mandatory=$false,
                    ValueFromRemainingArguments=$false)]
        [switch]$encrypt=$false,
    [Parameter( Position=6,
                    Mandatory=$false,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false )]
        [Int32]$connectionTimeout=15,
    [Parameter( Position=7,
                    Mandatory=$false,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false )]
        [bool]$open = $True,
	[Parameter(Mandatory=$false,Position=8)]
		[bool]$continueOnError = $true,
	[Parameter(Mandatory=$false,Position=9)]
		[switch]$help=$false
	)
    if ($help)
    {
        $msg = @"
Open a database conenction for use in a script.
"@
        Write-Host $msg
        return
    }

$databaseConnection = new-object System.Data.SqlClient.SqlConnection
$_connectionStringServer = "Server=$databaseServer;"
if ([string]::IsNullOrEmpty($databaseAccountLogin)) {
    $_connectionStringCredentials = "Integrated Security=true;"
} else {
    if ([string]::IsNullOrEmpty($databaseAccountLoginDomain)) {
        # No Domain Supplied must be using Sql Login
        $_databaseAccountLogin = $databaseAccountLogin
    } else {
        $_databaseAccountLogin = "$($databaseAccountLoginDomain)\$($databaseAccountLogin)"
    }
    $_connectionStringCredentials = "User Id=$_databaseAccountLogin;Password=$databaseAccountLoginPassword;"
}
$_connectionStringInitialCatalog = "Initial Catalog=$database;"
$connectionString = "$($_connectionStringServer)$_connectionStringCredentials$_connectionStringInitialCatalog"
Write-Verbose "Connection String: $connectionString"

$databaseConnection.ConnectionString = $connectionString

#Following EventHandler is used for PRINT and RAISERROR T-SQL statements. Executed when -Verbose parameter specified by caller
if ($PSBoundParameters.Verbose)
{
    $conn.FireInfoMessageEventOnUserErrors=$true
    $handler = [System.Data.SqlClient.SqlInfoMessageEventHandler] { Write-Verbose "$($_)" }
    $conn.add_InfoMessage($handler)
}

if($Open)
{
	Try
	{
		$databaseConnection.Open();
	}
	Catch
	{
		Write-Error $_;
		continue;
	}
}

write-Verbose "Created SQLConnection:`n$($databaseConnection | Out-String)";

$databaseConnection;

}

