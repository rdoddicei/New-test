function exec-sqlfile($filepath,$databaseConnection,$timeout=18000,[switch]$help,$echoFilePath=$true,$suppressOutput=$false,[Parameter(Mandatory=$True)][bool]$continueOnError=$false)
{
    if ($help)
    {
        $msg = @"
        Execute a specified .sql file. Requires a path to the file and an existing System.Data.SqlClient.SqlConnection.
        Return value will usually be a list of datarows.
"@
        Write-Host $msg
        return
    }

# $cmd=new-object system.Data.SqlClient.SqlCommand($sql,$databaseConnection)
# $cmd.CommandTimeout=$timeout

    $crlf = [System.Environment]::NewLine
    $sqlcmd = $databaseConnection.CreateCommand()
    $sqlcmd.CommandTimeout = $timeout
 
    $sql = ""
    if ($echoFilePath -eq $true)
    {
        $filePath
    }

    $content = Get-Content -PAth $filepath
    $lineCount = @(Get-Content $filepath).Length
    $currentLine = 0
    $inMultiLineComment = $false
	$inMultiLineString = $false
    $batch = 0

    foreach($line in $content)
    {
        $currentline++
        #$line

		if(([regex]::Matches($line, "'" )).count % 2 -gt 0)
		{
			if($inMultiLineString)
			{
				$characterStringClosing = $true;
			}

			$inMultiLineString = !$inMultiLineString;
			#$inMultiLineString
			#$characterStringClosing
			#$line
		}

		$testString = $line

        if($testString.ToLower().trim() -replace "(['])(?:(?=(\\?))\2.)*?\1" -match [Regex]::Escape("/*") -and $testString.ToLower().trim() -replace "(['])(?:(?=(\\?))\2.)*?\1" -notmatch [Regex]::Escape("*/") -and !$inMultiLineString)
        {
            #WRITE-HOST "Comment Started"
            $inMultiLineComment = $true;
        }

        if($inMultiLineComment -and $line.ToLower().trim() -match [Regex]::Escape("*/"))
        {
            #Write-Host "Comment Closed"

            $inMultiLineComment = $false
            $commentClosing = $true
        }

        #Write-Host "$currentline of $lineCount"
        if(($line.ToLower().trim() -notmatch "go--" -and $currentline -lt $lineCount) -or ($inMultilineComment -and $currentline -lt $lineCount))
        {
            $sql += "$line$crlf"
            #$commentClosing = $false

        }
        else
        {
            
            #first lets replace the go so we don't generate a syntax error. The closing comment may be after the go though.
            $sql += $($line.trim() -replace "go--.*");
          
            #If we are ending a multiline comment on the same line as a batch separator we may need to close the comment block
            if($commentClosing)
            {
            
                #now we should check to see if the replacement left us without a closing comment and if so we need to add one.
                if($line.ToLower().trim() -replace "go--.*" -notmatch [Regex]::Escape("*/"))
                {
                    $sql += "*/"
                }

            }

            $batch++          
            #WRITE-HOST "################################################################################"
            #Write-HOST "Batch  $batch"
            #$sql

            if ($sql -ne "") #don't execute if $sql is empty
            {
                $sqlcmd.CommandText = $sql

				try
				{
					$reader = $sqlcmd.ExecuteReader()
					if (!($suppressOutput))
					{
						#output the sql resultsets, if any, to stdout
						while($reader.HasRows)
						{
							while ($reader.Read())
							{
								for ($i=0; $i -lt $reader.FieldCount; $i++)
								{ #todo: this doesn't handle multicolumn selects very well now (just prints one value at a time),
									$reader.GetValue($i) #nor does it show column headers. do better if we need it to.
								}
							}
							$reader.NextResult() | Out-Null
						}
					}
					$reader.Close();
				}
				catch
				{
                    if($_.Exception.InnerException.Number -eq 100000)
			        {
				        Write-Output $_.Exception.GetBaseException();				
			        }
			        else
			        {
					    if ($continueOnError)
					    {
						    Write-Host $sql
						    Write-Host $PSItem;
					    }
					
					    else
					    {
						    #Write-Error $sql
						    Write-Error $PSItem;
						    exit 1
					    }
                    }
				}
				$sql = "";
            }
        
        }

        $commentClosing = $false
		$characterStringClosing = $false
        
    }

# $ds=New-Object system.Data.DataSet
# $da=New-Object system.Data.SqlClient.SqlDataAdapter($cmd)
# $da.fill($ds) | Out-Null
 
# return $ds
}
