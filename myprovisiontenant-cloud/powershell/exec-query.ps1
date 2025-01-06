function exec-query( $sql,$parameters=@{},$databaseConnection,$timeout=1800,[switch]$help,[Parameter(Mandatory=$True)][bool]$continueOnError=$false)
{
    if ($help)
    {
        $msg = @"
Execute a sql statement.  Parameters are allowed.
Input parameters should be a dictionary of parameter names and values.
Return value will usually be a list of datarows.
"@
        Write-Host $msg
        return
    }
		
	$cmd=new-object system.Data.SqlClient.SqlCommand($sql,$databaseConnection)
	$cmd.CommandTimeout=$timeout
	foreach($p in $parameters.Keys)
	{
		$value = $null;
		if($parameters[$p] -eq $null -or $parameters[$p] -eq [system.dbnull]::value) {$value = [system.dbnull]::value} ELSE {$value = $parameters[$p]}
		#Write-output "$($p) = '$($value)'";
		[Void]$cmd.Parameters.AddWithValue("@$p",$value);
	}
	$ds=New-Object system.Data.DataSet
	$da=New-Object system.Data.SqlClient.SqlDataAdapter($cmd)
	try 
	{
		[Void]$da.fill($ds)
	}
	catch [Exception]
	{
		$ex = $_.Exception | Format-List -force | Out-String;
		$parms = $parameters  | Format-Table | Out-String;
		Write-Host $sql
		Write-Host $parms;
		Write-Host $ex;
		if ($continueOnError -eq $false)
		{
			exit 1
		}
	}

	return $ds.Tables

}
