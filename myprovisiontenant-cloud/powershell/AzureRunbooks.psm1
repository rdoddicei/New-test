function ExecuteRunbookEXEC_BMRAMControl
{[CmdletBinding()]
 <#Check the subscription in which the script is being executed#>
 <#This only works if it's ran on an Azure VM#>
 <#Returns the name of the subscription#>
 Param
    (
        [Parameter(Mandatory=$true)]
        [string] $clusterNamePrefix
    )
    Import-Module DBAFunctions

    $subscriptionName = GetAzureSubscription

    <#set some variables depending on subscription#>
    if($subscriptionName -eq "BMQR-BPT-DEVELOPMENT")
    {
        $automationAccount = "CloudAutomation"
        
    }
    elseif($subscriptionName -eq "BMQR-BPT-PRODUCTION")
    {
        $automationAccount = "CloudAutomationPROD"
    }

    $secondarySvr = "$clusterNamePrefix-sql-1"
    $hybridWorker = "$secondarySvr`_WorkerGroup"
	
	$runbookParams = @{
		subscriptionName = $subscriptionName
		clusterNamePrefix = $clusterNamePrefix
	}

	# Set up parameters for the Start-AzAutomationRunbook cmdlet
	$startParams = @{
		ResourceGroupName = 'BMQR'
		AutomationAccountName = $automationAccount
		Name = 'EXEC_BMRAMControl'
		RunOn = $hybridWorker
		Parameters= $runbookParams
	}
	try 
	{
		$job = Start-AzAutomationRunbook @startParams -wait -erroraction "stop"
	}
	catch
	{
        $tempError = $error[0].Exception
		#$tempError
		if ($tempError -notlike "*Job completion maximum wait time reached*")
		{	
			$error[0]
		}
	}

}
<############################# END OF FUNCTION ###################################>



function ExecuteRunbookEXEC_BACKUPS
{[CmdletBinding()]
 <#Check the subscription in which the script is being executed#>
 <#This only works if it's ran on an Azure VM#>
 <#Returns the name of the subscription#>
 Param
    (
        [Parameter(Mandatory=$true)]
        [string] $clusterNamePrefix,

        [Parameter(Mandatory=$true)]
        [string] $customerName
    )
    Import-Module DBAFunctions

    $subscriptionName = GetAzureSubscription

    <#set some variables depending on subscription#>
    if($subscriptionName -eq "BMQR-BPT-DEVELOPMENT")
    {
        $automationAccount = "CloudAutomation"
        
    }
    elseif($subscriptionName -eq "BMQR-BPT-PRODUCTION")
    {
        $automationAccount = "CloudAutomationPROD"
    }

    $secondarySvr = "$clusterNamePrefix-sql-1"
    $hybridWorker = "$secondarySvr`_WorkerGroup"
	
	$runbookParams = @{
		subscriptionName = $subscriptionName
        backupType = "FULL"
		clusterNamePrefix = $clusterNamePrefix
        customerID = $customerName
	}

	# Set up parameters for the Start-AzAutomationRunbook cmdlet
	$startParams = @{
		ResourceGroupName = 'BMQR'
		AutomationAccountName = $automationAccount
		Name = 'EXEC_BACKUPS'
		RunOn = $hybridWorker
		Parameters= $runbookParams
	}
	try 
	{
		$job = Start-AzAutomationRunbook @startParams -erroraction "stop"
	}
	catch
	{
        $tempError = $error[0].Exception
		#$tempError
		if ($tempError -notlike "*Job completion maximum wait time reached*")
		{	
			$error[0]
		}
	}

}
<############################# END OF FUNCTION ###################################>


Export-ModuleMember -Function ExecuteRunbookEXEC_BMRAMControl
Export-ModuleMember -Function ExecuteRunbookEXEC_BACKUPS
