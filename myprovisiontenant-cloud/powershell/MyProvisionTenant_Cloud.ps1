#Updated Powershell Code
Set-Location $PSScriptRoot;

#Load needed modules
Import-Module -Name .\HelperFunctions.ps1;
Import-Module -Name .\exec-query.ps1;
Import-Module -Name .\New-SqlConnection.ps1;
Import-Module -Name .\BMQRAuthentication.psm1;
Import-Module -Name .\BMQRAuth0.psm1;
Import-Module SqlServer -WarningAction SilentlyContinue -DisableNameChecking
Import-Module -Name .\DBAFunctions.psm1;
Import-Module -Name .\AzureRunbooks.psm1;
#Import-Module Sqlps -WarningAction SilentlyContinue -DisableNameChecking
#######################################
#Variables
#######################################
# Access the environment variables in PowerShell

$clientId = $env:AZURE_CLIENT_ID
$tenantId = $env:AZURE_TENANT_ID
$clientSecret = $env:AZURE_CLIENT_SECRET

if (-not $clientId -or -not $tenantId -or -not $clientSecret) {
    Write-Error "Required Azure environment variables are missing."
    exit 1
}
Write-Host "customerID: $env:CUSTOMER_ID"
Write-Host "customerName: $env:CUSTOMER_NAME"
Write-Host "customerSN: $env:CUSTOMER_SN"
Write-Host "environmentType: $env:ENVIRONMENT_TYPE"
Write-Host "deploymentMode: $env:DEPLOYMENT_MODE"
Write-Host "customertypes: $env:CUSTOMER_TYPE"
Write-Host "subscriptionName: $env:SUBSCRIPTION_NAME"
Write-Host "region: $env:REGION"
Write-Host "regionAbbrev: $env:REGION_ABBREV"
Write-Host "resourceGroup: $env:RESOURCE_GROUP"
$auth0ConnectionName = "coolblue-waad"
if($customertype -eq "CLOUD_ESSENTIALS"){
$caption = "DEVELOPMENT"
}else{
$caption = $env:environmentType}
$applicationEnvironment = $caption
$applicationEnvironmentBackground = "#5e6a71"
$applicationDatabaseName = $env:customerID + "_RAMDB";
$tenantName = $env:customerName;
$subDomain = $env:customerID;
$systemBuildMode = $false;
$subscriptionName = $env:subscriptionName

Write-Host "Script will be executed the Subscription name - $subscriptionName"
if($subscriptionName -eq "Other")
  {
  $OtherSub = "Y"
  $subscriptionName = Read-Host "Enter the Subscription Name"
  }
$region = "$env:region"
$regAbbrev = "$env:regionAbbrev"
$resourceGroup = "$env:resourceGroup"
Write-Host "Script has executed and get the Region - $env:region"

# Ensure the Azure environment variables are set
$clientId = $env:AZURE_CLIENT_ID
$tenantId = $env:AZURE_TENANT_ID
$clientSecret = $env:AZURE_CLIENT_SECRET

if (-not $clientId -or -not $tenantId -or -not $clientSecret) {
    Write-Error "Required Azure environment variables are missing."
    exit 1
}

# Create a PSCredential object for Service Principal authentication
$secureClientSecret = ConvertTo-SecureString $clientSecret -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($clientId, $secureClientSecret)

# Ensure required customer environment variables are set
if (-not $env:customerID -or -not $env:customerName) {
    Write-Error "Required customer environment variables are missing."
    exit 1
}

# Authentication steps
Write-Host "Service principal authentication added successfully"

# Connect to Azure using the service principal
Connect-AzAccount -ServicePrincipal -TenantId $tenantId -ApplicationId $clientId -Credential $credential
Write-Host "Successfully connected to Azure."

# Call the BMQR Authentication function (assuming Add-BmqrAuthentication is a valid function)
Add-BmqrAuthentication -SubscriptionName $env:subscriptionName

# Select the Azure subscription
Select-AzSubscription -SubscriptionId $env:subscriptionName -TenantId $tenantId
Set-AzContext -SubscriptionId $env:subscriptionName

Write-Host "Azure context set successfully."


$appEnvResourceGroup = $env:appEnvResourceGroup.ResourceGroupName   
$appGatewayName = "$env:appEnvResourceGroup"
if($subscriptionName -eq "BMQR-BPT-DEVELOPMENT")
    {$DNSZone = "bluemountainsoftware.com"
     $auth0tenant = "bluemountainsoftware.auth0.com"
     $issuer = "https://bluemountainsoftware.auth0.com/"
     $mobileBundleIdentifier = "bluemountain"
     $keyvault = "BMQRKeyVaultDev"
     $subAbbrev = "DEV"
     $isproduction = "0"
     $DNSsubscription = "BMQR-BPT-PRODUCTION"
     $SA = "sharedwebcontent"
     $bmqradminPasswordSecret = "bmqradminDEV"
     $isDevelopmentEnvironment = $true
     $clusterTargetsFile = "`.\ClusterTargetsR4_DEV.txt"
     $tenantDatabaseServer = "r4-01-eus-azsqlserver-bmqrdev.database.windows.net"
     $tenantDBlogin = "bmqrdevadmin"
     $bmqrTenantDBUserPasswordSecret = "bmqrdevTenantDBUserPassword"
     $customError502Url = "https://bmqrtest.blob.core.windows.net/maintenancealert/index.html"
     $apimgtsvcName = "r4-01-eus-apimgtsvc-01" 
     $apimgtsvcURL = "https://r4-01-eus-apimgtsvc-01.azure-api.net"
     $servicebusName = "r4-01-eus-servicebus"
     $automationAccount = "CloudAutomation"
    }
 if($subscriptionName -eq "BMQR-BPT-PRODUCTION")
    {$DNSZone = "coolbluecloud.com"
     $auth0tenant = "coolbluecloud.auth0.com"
     $issuer = "https://coolbluecloud.auth0.com/"
     $mobileBundleIdentifier = "bluemountain"
     $keyvault = "BMQRKeyVault"
     $subAbbrev = "PROD"
     $isproduction = "1"
     $DNSsubscription = "BMQR-BPT-PRODUCTION"
     $SA = "bmqrdatastorage"
     $bmqradminPasswordSecret = "bmqradminPROD"
     $isDevelopmentEnvironment = $false
     $clusterTargetsFile = "`.\ClusterTargetsR4.txt"
     $tenantDatabaseServer = "r4-01-eus-azsqlserver-bmqrprod.database.windows.net"
     $tenantDBlogin = "bmqrprodadmin"
     $bmqrTenantDBUserPasswordSecret = "bmqrprodTenantDBUserPassword"
     $customError502Url = "https://bmqrfiles.blob.core.windows.net/maintenancealert/index.html"
     $apimgtsvcName = "r4-01-eus-apimgtsvc-02" 
     $apimgtsvcURL = "https://r4-01-eus-apimgtsvc-02.azure-api.net"
     $servicebusName = "r4-01-eus-01-servicebus"
     $automationAccount = "CloudAutomationPROD"
    }
$subAbbrevLower = $subAbbrev.ToLower()

#find cluster from bmramcontrol, and the server info
Write-Host "Script has executed and finding the access token"

$ControlDatabase = "BMRAMControl"
$access_token = (Get-AzAccessToken -ResourceUrl https://database.windows.net).Token
$query = "select ClusterNamePrefix from tblclusters where ApplicationGroup = 'R4'"
$clusterNames = invoke-sqlcmd -ServerInstance $tenantDatabaseServer -Database $ControlDatabase -AccessToken $access_token -Query $query
$SourceCluster = $clusterNames | Out-GridView -PassThru -Title "What Cluster does the customer reside on?"
$clusterPrefix = "Cluster-" + $SourceCluster.ClusterNamePrefix
$clusterPrefixInfo =  $SourceCluster.ClusterNamePrefix
$storageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroup -Name $backupDestAccount 
#define variables by reading cluster targets table for R4
$tableName = "ClusterTargets"
$context = $storageAccount.Context
$cloudTable = (Get-AzStorageTable -Name $tableName -Context $context).CloudTable
$row = Get-AzTableRow -Table $cloudTable | Where-Object{$_.ClusterNamePrefix -eq $SourceCluster.ClusterNamePrefix}
$ag = $row.AvailabilityGroup
$primarySvr = $row.PrimarySvr 
$secondarySvr = $row.SecondarySvr 
$listener = $row.ListenerName
$tenantListenerIP = $row.ListenerIP
$targetRptSvrURL = $row.ReportServerURL

Set-Location $PSScriptRoot;
Write-Host "Script has executed at line 133"
Get-WebConfigApiToken -tenant $auth0tenant -vaultName $keyvault
Get-InstallationApiToken -tenant $auth0tenant -vaultName $keyvault
#Select-AzSubscription -Subscription $subscriptionName -Tenant $azureTenantid
$logDate = Get-Date -UFormat "%d%b%Y_%T" | ForEach-Object  { $_ -replace ":", "_" }
$logfile = "\DeployLog_" + $customerID + "_" + $logDate + ".txt"
Write-Output "R4 deploy logfile name is " $logfile
$LogfileStorageAccountName = $SA
$LogileSharename = "\\$Global:backupDestAccount.file.core.windows.net\$Global:fileShare"
$LogfileFolder = Join-Path -Path "H:\" -ChildPath "CustomerDeployments" | Join-Path -ChildPath $customerID
if( -Not (Test-Path -Path $LogfileFolder ) )
{
    New-Item -ItemType directory -Path $LogfileFolder
}
$LogfileStorageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $resourceGroup -AccountName  $LogfileStorageAccountName)| Where-Object {$_.KeyName -eq "key1"}
$LogfileStorageAccountKey  = $LogfileStorageAccountKey.Value
$logfile = $LogfileFolder + $logfile
$logfileDate = Get-date
$domainController="ad-primary-dc"
$subnetName = $clusterPrefixInfo + "SqlSubnet"
$applicationDatabaseServer = $primarySvr
$tenantDatabaseName = "Tenant";
$landingDatabaseName = "Landing";
$managementDatabaseAccountLogin = "bmqradmin"
$managementDatabaseAccountLoginPassword = (Get-AzKeyVaultSecret -VaultName $vaultName -Name $bmqradminPasswordSecret ).SecretValue
$managementDatabaseAccountLoginPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($managementDatabaseAccountLoginPassword)) 
$managementDatabaseAccountLoginDomain = $null;
$TenantDatabaseAccountLoginPassword = (Get-AzKeyVaultSecret -VaultName $vaultName -Name $bmqrTenantDBUserPasswordSecret ).SecretValue
$TenantDatabaseAccountLoginPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($TenantDatabaseAccountLoginPassword)) 
$TenantDatabaseAccountLoginDomain = $null;
$r4AppUser = $clusterPrefixInfo + "_ramapp"
$r4ClusterAppUserPasswordSecret = $clusterPrefixInfo + "R4AppUserPassword"
$r4AppUserPassword = (Get-AzKeyVaultSecret -VaultName $vaultName -Name $r4ClusterAppUserPasswordSecret ).SecretValue
$r4AppUserPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($r4AppUserPassword)) 
$serviceAccountLogin = $r4AppUser;
$serviceAccountLoginPassword = $r4ClusterAppUserPasswordSecret
$serviceAccountLoginDomain = $null;
$databaseOwnerAccountDomain = $null;
$databaseOwnerAccount = "RamDatabaseOwner";
$reportUserLogin = "rpt$(Get-RandomCharacters -length 17 -characters 'abcdefghiklmnoprstuvwxyzABCDEFGHKLMNOPRSTUVWXYZ1234567890')";  #this is the report user on the datasource (SQL authentication)
$reportUserLoginPassword = (Get-AzKeyVaultSecret -VaultName $vaultName -Name ReportUserPassword ).SecretValue
$reportUserLoginPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($reportUserLoginPassword)) 
$loginlessUser = "usr$(Get-RandomCharacters -length 17 -characters 'abcdefghiklmnoprstuvwxyzABCDEFGHKLMNOPRSTUVWXYZ1234567890')";
$tenantApiKey = "$(Get-RandomCharacters -length 64 -characters 'abcdefghiklmnoprstuvwxyzABCDEFGHKLMNOPRSTUVWXYZ1234567890!@#$%^&*()_+~`{}|[]\:;<>?,./')";
$continueOnError = $false;
$ilbname = $clusterPrefixInfo + "-sql-ilb"
$ilbfeip = $clusterPrefixInfo + "-sql-ilbfe1"
$slb = Get-AzLoadBalancer -Name $ilbname -ResourceGroupName $resourcegroup
$connectionStringServerIp = $slb.FrontendIpConfigurations.PrivateIpAddress
$uriScheme = "https"
$uriHost = $servicebusName + ".servicebus.windows.net"
$uriPort = $null;
$uriPath = "messages"
$uriQuerystring = "messagetimeout=60"
$uriFragment = $null;
$httpVerb = "POST";
$requestHeaders = "<headers><header><name>Accept-Encoding</name><value>gzip, deflate</value></header><header><name>Cache-Control</name><value>no-cache</value></header><header><name>ContentType</name><value>application/json</value></header></headers>";
$serviceBusNamespace = $uriHost 
$serviceBusAccessPolicy = "SendSharedAccessKey";
$accessPolicyKey = Get-AzServiceBusKey -ResourceGroupName $resourcegroup -Namespace $servicebusName -Name $serviceBusAccessPolicy 
$accessPolicyKey = $accessPolicyKey.PrimaryKey
$accessTokenLifetime = "600";
$applicationDatabaseConnection=$null;
$tenantDatabaseConnection=$null;
$serverUrl = "https://$($subdomain)" + "." + $DNSZone;
$recordsPerPage = 50;
$BMQRAuthenticationSourceID = "CLOUD AUTHENTICATION"
$BMQRAuthenticationSourceName = "CLOUD AUTHENTICATION"
$BMQRPersonnelID = "BMQRAdmin"
$BMQRPersonnelName ="BMQR Admin User"
$BMQRPersonnelInitialWorkspaceID = "DefaultSystemWorkspace"
$BMQRPersonnelScopeID = "SYSTEM"
$BMQRPersonnelFirstName = "BMQR"
$BMQRPersonnelLastName = "Admin User"
$groupMemberships=$null
$groupMemberships+= ,(@("ADMINISTRATORS","SYSTEM"))
$groupMemberships+= ,(@("bpt_2.BatchUpdateAdministrator","SYSTEM"))
$CustomerAuthenticationSourceID = $customerID.ToUpper() + " CLOUD AUTHENTICATION";
$CustomerAuthenticationSourceName = $customerID.ToUpper() + " CLOUD AUTHENTICATION";
$BMQRPMPersonnelID = "BMQRPM"
$BMQRPMPersonnelName ="BMQR Project Manager"
$BMQRPMPersonnelFirstName = "BMQR"
$BMQRPMPersonnelLastName = "Project Manager"
$authenticationType = "AUTHCLOUD"
$remoteAccessRegistry = $true
$remoteAccessRegistryCustomer = $false
$BMQRAnalystPersonnelID = "BMQRAnalyst"
$BMQRAnalystPersonnelName ="BMQR Analyst"
$BMQRAnalystPersonnelFirstName = "BMQR"
$BMQRAnalystPersonnelLastName = "Analyst"
$BMQRAnalyst2PersonnelID = "BMQRAnalyst2"
$BMQRAnalyst2PersonnelName ="BMQR Analyst 2"
$BMQRAnalyst2PersonnelFirstName = "BMQR"
$BMQRAnalyst2PersonnelLastName = "Analyst2"
$BMQRAnalyst3PersonnelID = "BMQRAnalyst3"
$BMQRAnalyst3PersonnelName ="BMQR Analyst 3"
$BMQRAnalyst3PersonnelFirstName = "BMQR"
$BMQRAnalyst3PersonnelLastName = "Analyst3"
$authenticationPropertyMapsToAdd=$null
$authenticationPropertyMapsToAdd+= ,(@("Email","Email"))
$authenticationPropertyMapsToAdd+= ,(@("Given Name","FirstName"))
$authenticationPropertyMapsToAdd+= ,(@("Family Name","LastName"))
$authenticationPropertyMapsToAdd+= ,(@("Full Name","Name"))
$authGrantEmailMailFormat = "HTML"
$authGrantEmailImportance = "Normal"
$authGrantEmailMessageSubject = $customerName + " (" + $customerID + ") Remote Assistance Request has been Submitted";
$authGrantEmailMessageBody = "
Attention:
$customerName ($customerID) has provided an authorization grant for remote assistance.  
Please review the following details of this request:
Customer Name: $customerName
CustomerID: $customerID
Serial Number:  $customerSN
Customer URL: $serverUrl
Entered By:
Requestor email:
Expiration Date:
Comments:
"
$authGrantEmailRecipients = "BMQRRemoteAssistance@coolblue.com";
$authGrantEmailBCCRecipients = "";
$reportingUserID  = $reportUserLogin; #this is the domain report user that will have browser rights for reports, Windows authentication
$reportingUserDomain = "bmqr.local"
$reportingUserPassword = $reportUserLoginPassword
$URL = "http://$tenantListenerIP/reportserver" 
$reportServer = $URL
$authorizationGrantID = "InitialInstallGrant";
$authorizationGrantName = "Initial Install Grant";
$expirationDate = (Get-Date).AddDays(730).ToString("yyyy-MM-dd") #2 year login grant
$comments = "Authorization Grant to allow BMQR users to access the system following initial installation"
$deployVersion="6.3.6"   #this correlates to a folder in H:\deploymentsource
if (($result = Read-Host "What version of the RAMDB are you deploying or press enter to accept default value `"$deployVersion`"") -eq '') {$deployVersion} else {$deployVersion= $result } 
$bmramDB = "$customerID`_RAMDB"
$deployRootDir = "C:\"
$deployRootDirH = "H:\"
$deploySourceRootDir= Join-Path -Path $deployRootDirH -ChildPath "DeploymentSource"  #changed to H
$deploySourceDir= Join-Path -Path $deployRootDirH -ChildPath "DeploymentSource" | Join-Path -ChildPath $deployVersion\DB  #changed to H:\DeploymentSource\R3SR0\DB
$deployScriptDir= Join-Path -Path $deployRootDir -ChildPath "DeploymentScripts"
$deployReportDir= Join-Path -Path $deployRootDirH -ChildPath "CustomerDeployments"  #changed from C to H
$deployReportSourceDir= Join-Path -Path $deployRootDirH -ChildPath "DeploymentSource" | Join-Path -ChildPath $deployVersion\Reports
$webAppResourceType = "Microsoft.Web/sites"
$ramWebApps = (Get-AzResource -ResourceGroupName $appEnvResourceGroup -ResourceType $webAppResourceType | Where-Object{$_.Name -like "*-ram-*"}).Name
$ramWebApp = $ramWebApps | Out-GridView -Title "Select the Ram Web App for the Customer" -PassThru; Write-Output $ramWebApp
$signalrWebApps = (Get-AzResource -ResourceGroupName $appEnvResourceGroup -ResourceType $webAppResourceType | Where-Object{$_.Name -like "*-signalr-*"}).Name
$signalrWebApp = $signalrWebApps | Out-GridView -Title "Select the SignalR Web App for the Customer" -PassThru; Write-Output $signalrWebApp
$webAPIWebApps = (Get-AzResource -ResourceGroupName $appEnvResourceGroup -ResourceType $webAppResourceType | Where-Object{$_.Name -like "*-webapi-*"}).Name
$webAPIWebApp = $webAPIWebApps | Out-GridView -Title "Select the WebAPI Web App for the Customer" -PassThru; Write-Output $webAPIWebApp
$ramreportsWebApps = (Get-AzResource -ResourceGroupName $appEnvResourceGroup -ResourceType $webAppResourceType | Where-Object{$_.Name -like "*-ramreports-*"}).Name
$ramreportsWebApp = $ramreportsWebApps | Out-GridView -Title "Select the RamReports Web App for the Customer" -PassThru; Write-Output $ramreportsWebApp
$serviceBusTopics = (Get-AzServiceBusTopic -ResourceGroupName $resourceGroup -Namespace $serviceBusName | Where-Object{$_.Name -like "*-automations-*"}).Name
$serviceBusTopic = $serviceBusTopics | Out-GridView -Title "Select the Automation topic to use" -PassThru; Write-Output $serviceBusTopic        
$batchServiceBusTopics = (Get-AzServiceBusTopic -ResourceGroupName $resourceGroup -Namespace $serviceBusName | Where-Object{$_.Name -like "*-batch-*"}).Name
$batchServiceBusTopic = $batchServiceBusTopics | Out-GridView -Title "Select the Batch topic to use" -PassThru; Write-Output $batchServiceBusTopic        
$notificationServiceBusTopics = (Get-AzServiceBusTopic -ResourceGroupName $resourceGroup -Namespace $serviceBusName | Where-Object{$_.Name -like "*-notifications-*"}).Name
$notificationBusTopic = $notificationServiceBusTopics | Out-GridView -Title "Select the Notifications topic to use" -PassThru; Write-Output $notificationBusTopic  
$controlMessageTopic = $notificationBusTopic
$BMQRAdminUser = if ($env:BMQR_ADMIN_USER) { $env:BMQR_ADMIN_USER } else { Read-Host "Enter Your Personal Microsoft username (i.e. user@coolblue.com)" }
$DNSTenantID = $azureTenantID
Connect-AzAccount -Identity
Select-AzSubscription -Subscription $DNSSubscription -Tenant $azureTenantid
Set-AzContext -Subscription $DNSSubscription
$aliasGateway = $appGatewayName + "." + $DNSZone
$BMQRPMUser = if ($env:BMQR_PM_USER) { $env:BMQR_PM_USER } else { Read-Host "What is the username (i.e. username@coolblue.com) of the Blue Mountain Project Manager for this customer?" }
sleep 5
Write-Host "Script has executed till variables are assigned"
#######################################################################################################################

#Bills way of connecting to the tenant database to run scripts against.

Set-Location $PSScriptRoot;
$closeTenantDbConnection = $false;
if (!$tenantDatabaseConnection) #if no $databaseConnection was passed (e.g. if this script is being run directly), initialize it
{
	$tenantDatabaseConnection = new-object System.Data.SqlClient.SqlConnection;
	$tenantDatabaseConnection = New-SqlConnection -databaseServer $tenantDatabaseServer `
												  -databaseAccountLogin $tenantDBlogin `
												  -databaseAccountLoginPassword $TenantDatabaseAccountLoginPassword `
												  -databaseAccountLoginDomain $TenantDatabaseAccountLoginDomain `
												  -database $tenantDatabaseName;
    $closeTenantDbConnection = $true;
}
#######################################################################################################################

#Bills way of connecting to the tenant BMRAMControl to run scripts against.

$closeBMRAMControlConnection =$false;
if (!$BMRAMControlConnection) #if no $databaseConnection was passed (e.g. if this script is being run directly), initialize it
{
	$BMRAMControlConnection = new-object System.Data.SqlClient.SqlConnection;
	$BMRAMControlConnection = New-SqlConnection -databaseServer $primarySvr `
												  -databaseAccountLogin $managementDatabaseAccountLogin `
												  -databaseAccountLoginPassword $managementDatabaseAccountLoginPassword `
												  -databaseAccountLoginDomain $managementDatabaseAccountLoginDomain `
												  -database "BMRAMControl";
    $closeBMRAMControlConnection = $true;
}

#############################################################################################################################
$message = "
#########################################################################################
$logfileDate

Deployment of Customer: $customerID
Deployed by:  $BMQRAdminUser
#########################################################################################
Provisioning Script Version = 6.3.6
Logfile Location =  $logfile
storage account = $SA
resourceGroup = $resourceGroup
customerID = $customerID
customerName = $customerName
customerSN = $customerSN
customerType = $customertype
environmentType = $environmentType
clusterPrefix = $clusterPrefix
serverUrl = $serverUrl
subAbbrev = $subAbbrev
subscriptionName = $subscriptionName
auth0tenant = $auth0tenant
CLOUD AUTHENTICATION source connection = $auth0ConnectionName 
DNSZone = $DNSZone
DNSsubscription = $DNSsubscription
vaultName = $keyvault
serviceBusName = $servicebusName
deployDBVersion = $deployVersion
bmramDB = $bmramDB
deploymentMode = $deploymentmode
Using Web Apps:
  RAM Web App: $ramWebApp
  SignalR Web App: $signalrWebApp
  RAMReports Web App: $ramreportsWebApp
  WEBAPI Web App = $webAPIWebApp
Using Service Bus: $serviceBusName
  Topics:
  Automations = $serviceBusTopic
  Notifications = $controlMessageTopic
  Batch = $batchServiceBusTopic
primarySvr = $primarySvr
secondarySvr = $secondarySvr
tenantDatabaseServer listener = $tenantDatabaseServer
$clusterPrefix listener IP = $tenantListenerIP
ag = $ag
appGatewayName = $appGatewayName
managementDatabaseAccountLogin =  $managementDatabaseAccountLogin
API Management Service =  $apimgtsvcName
     Mobile API record = $customerID`_mobile
BMQRAdmin User = $BMQRAdminUser
BMQRPM User = $BMQRPMUser
#########################################################################################
VERIFY PARAMETERS BEFORE CONTINUING!!!
#########################################################################################"

Write-Output $message
pause
$message | Out-File $logfile
Write-Host "Script has executed and deployment has been started"
if( $deploymentMode -eq "BPT"){
$reportpath1 = "/$customerID/R4BPTemplate"
$reportpath = $reportpath1
}else{
$message = "

Reporting ALERT!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

Not setting the report path yet because we are not deploying reports for deployment modes other than BPT!!!!
NOTE FOR FUTURE NO_BPT deployment mode, after deploying reports for the first time, we will have to update the Tenant DB
with the reportPath (i.e. /<moniker>/<reportFolderName>)

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

"  
$message
$message | Out-File $logfile -Append
}

#######################################################################################################################
#Limited mode in Production,  prompt in DEV subscription
$systemConfigurationAccess = ""
if($isDevelopmentEnvironment)
	{
		$sysConfigYN = "Y"
        if (($result = Read-Host "Do you want to provision with non-admin users in Limited Mode (bmram.cfgRegistry's SystemConfigurationAccess Key exists) (Y or N)? or press enter to accept default value `"$sysConfigYN`"") -eq '') {$sysConfigYN} else {$sysConfigYN= $result } 
          if($sysConfigYN -eq "Y")
          {
            #deploy Limited mode in the Dev subscription
            $systemConfigurationAccess = Get-Content -Path .\SystemConfigurationAccess.json  -Raw;
            $message = "
            Alert!!!! 
            Turning off System Config Access to all except for BMQR Admin users (LIMITED MODE)

               bmram.cfgregistry has KeyName = SystemConfigurationAccess
               DEVELOPMENT subscription"
            Write-Output $message
            $message | Out-File $logfile -Append 
          }else{
           #deploy Full access mode in the DEV subscription
           $message = "  
            System Config Access available for all users 
             bmram.cfgregistry has NO KeyName = SystemConfigurationAccess
             DEVELOPMENT subscription"
           Write-Output $message
           $message | Out-File $logfile -Append
        }     
	}else{
      #deploy Limited mode in the PROD subscription
      $systemConfigurationAccess = Get-Content -Path .\SystemConfigurationAccess.json  -Raw;

    }


#########################################################################################################################################################################################################################################
Write-Host "Script has executed at line 444 and auth0 provising has been started"
#Creating Auth0 Application $customerID in the Auth0 tenant: $auth0tenant
$message =
"
Creating Auth0 Application $customerID in the Auth0 tenant: $auth0tenant
Setting with Grant Types: Implicit, authorization_code, refresh_token
OIDC Conformant: true
Use Auth0 instead of the IdP to do SSO (sso): false
"
Write-Output $message
$message | Out-File $logfile -Append

$mobilecallback = "com." + $mobileBundleIdentifier + ".rammobile.auth0://" + $auth0tenant + "/ios/com." + $mobileBundleIdentifier + ".rammobile/callback"
$mobilecallback2 = "rammobile.auth0://" + $auth0tenant + "/android/com." + $mobileBundleIdentifier + ".rammobileapp/callback"

$authHeader = 
@{
    "Content-Type" = "application/json"
    "Authorization" = "Bearer " + $auth0InstallationApiToken
 }

$newApplicationBody =
"{
""name"":""$customerID"",
""sso"":false,
""callbacks"":[""$serverUrl"", ""$serverUrl/Profile/ClientCallback"", ""$mobilecallback"", ""$mobilecallback2""],
""oidc_conformant"": true,
""sso"":false, 
""allowed_logout_urls"":[],
""allowed_clients"":[],
""allowed_origins"":[],
""jwt_configuration"":{""alg"":""RS256"", ""lifetime_in_seconds"": 36000, ""secret_encoded"": false},
""web_origins"":[""$serverUrl""],
""token_endpoint_auth_method"":""none"", 
""grant_types"":[""implicit"",""authorization_code"", ""refresh_token""],
""custom_login_page_on"":true,
""app_type"":""spa""
}"

$uri = "https://$auth0tenant/api/v2/clients"
$newA0App = (Invoke-RestMethod -Uri $uri -Headers $authHeader -Method POST -Body $newApplicationBody)

$clientID = $newA0App.client_id

#######################################################################################################################
#Add connection to customer Auth application
Write-Host "Script has executed at line 490 and start adding connection to customer auth"
$message = " Finding the $auth0ConnectionName connection in Auth0 tenant "
Write-Output $message
$message | Out-File $logfile -Append #CHANGE IN VARIABLE VALUE #NEW CREATION
$uri = "https://$auth0tenant/api/v2/connections?name=$auth0ConnectionName"
$GetCoolblueConn = (Invoke-RestMethod -Uri $uri -Headers $authHeader -Method GET)
$GetConnClients = $GetCoolblueConn.enabled_clients 
$results = @()
foreach($enabledclients in $GetConnClients){
          $GetConnClients2 = @{enabledclients = $enabledclients}
                     
        $results += New-Object PSObject -Property $GetConnClients2
        $clients = @()
        $client = @{enabledclients = $clientid}
        $clients += New-Object PSObject -Property $client
        }
       
        #$filepath = "C:\Environment\Scripts\enabledclientsforauth0connection.csv"
        $filepath = ".\EnabledClientsForAuth0Connection.csv"
        $results | Export-csv -Path   $filepath  -NoTypeInformation 
        Start-Sleep -Seconds 5
        $clients | Export-csv -Path   $filepath   -NoTypeInformation  -Append 

        $enabledclients = Get-Content $filepath | select -Skip 1 
        $enabledclients2  = $enabledclients -join ','
$GetCoolblueConnID = $GetCoolblueConn.id  

if([string]::IsNullOrEmpty($enabledclients2)) 
     { 
       $message = "Do not continue, the enabledclients2 variable should not be empty! Contact Cloud Lead before continuing"
       Write-Output $message
       $message | Out-File $logfile -Append
       pause
     }

$newConnectionBody = 
"{
""enabled_clients"": [$enabledclients2]
}"

#######################################################################################################################
#enable the coolblue-waad connection for the application or vice versa
$message =
"Turning on $auth0ConnectionName connection for the Auth0 application $customerID"

Write-Output $message
$message | Out-File $logfile -Append

$uri = "https://$auth0tenant/api/v2/connections/$GetCoolblueConnID"
$updateConnection = (Invoke-RestMethod -Uri $uri -Headers $authHeader -Method PATCH -Body $newConnectionBody)

#######################################################################################################################
#install RAM DB

Write-Host "Script has executed at line 544 and RAM DB installation has been started"

$message =
"Installing RAM Database & Copying RAMDB_Clean.bak to G:\Backups\RAMDB"

Write-Output $message
$message | Out-File $logfile -Append

$source = "$deploySourceDir\RAMDB_Clean.bak"  
$target = "\\$primarySvr\G$\Backups\RAMDB"
if (!(Test-Path $target -PathType container))
    { New-Item -ItemType directory -Path $target }
Copy-Item $source -Destination $target -Force 

"Restoring/Creating $bmramDB "
 $filepath = "N'G:\Backups\RAMDB\RAMDB_Clean.bak'"
 $filepath2 = "N'F:\data\" + $bmramDB + ".mdf'"
 $filepath3 = "N'G:\log\" + $bmramDB + "_log.ldf'"

 #GET LOGICALNAMES
$SQL = "
DECLARE @Table TABLE (
    LogicalName varchar(128),
    [PhysicalName] varchar(128), 
    [Type] varchar, 
    [FileGroupName] varchar(128), 
    [Size] varchar(128),
    [MaxSize] varchar(128), 
    [FileId]varchar(128), 
    [CreateLSN]varchar(128), 
    [DropLSN]varchar(128), 
    [UniqueId]varchar(128), 
    [ReadOnlyLSN]varchar(128), 
    [ReadWriteLSN]varchar(128),
    [BackupSizeInBytes]varchar(128), 
    [SourceBlockSize]varchar(128), 
    [FileGroupId]varchar(128), 
    [LogGroupGUID]varchar(128), 
    [DifferentialBaseLSN]varchar(128), 
    [DifferentialBaseGUID]varchar(128), 
    [IsReadOnly]varchar(128), 
    [IsPresent]varchar(128), 
    [TDEThumbprint]varchar(128),
    [SnapshotUrl]varchar(128)
)
DECLARE @Path varchar(1000)=$filepath
DECLARE @LogicalNameData varchar(128),@LogicalNameLog varchar(128)
INSERT INTO @table
EXEC('
RESTORE FILELISTONLY
   FROM DISK=''' +@Path+ '''
   ')

   SET @LogicalNameData=(SELECT LogicalName FROM @Table WHERE Type='D')
   SET @LogicalNameLog=(SELECT LogicalName FROM @Table WHERE Type='L')

SELECT @LogicalNameData LGLName,  @LogicalNameLog LGLLogName
"
#$LGLNAMEQRY = exec-query -conn $conn -sql $sql -continueOnError $continueOnError

$LGLNAMEQRY = Invoke-sqlcmd $sql -ServerInstance $primarySvr -QueryTimeout 360
$Lglname = $LGLNAMEQRY.LGLName
$LglLogname = $LGLNAMEQRY.LGLLogName
$Lglname2 = $Lglname
$LglLogname2 = $LglLogname
$Lglname = "N'" + $Lglname + "'"
$LglLogname = "N'" + $LglLogname + "'"
 $sql4 = " 
 USE [master]
 RESTORE DATABASE [$bmramDB] 
 FROM DISK = " + $filepath + " WITH FILE = 1 ,
  MOVE "  + $Lglname + " TO " + $filepath2 + ", 
  MOVE "  + $LglLogname + " TO " + $filepath3 + ",
    NOUNLOAD,  REPLACE,  STATS = 5"
Invoke-sqlcmd $sql4 -ServerInstance $primarySvr -QueryTimeout 360
Sleep 20
Invoke-Sqlcmd -ServerInstance $primarySvr -Database master -Query "ALTER DATABASE [$bmramDB]  MODIFY FILE ( NAME = $Lglname2, NEWNAME = $bmramDB );"
Invoke-Sqlcmd -ServerInstance $primarySvr -Database master -Query "ALTER DATABASE $bmramDB MODIFY FILE ( NAME = $LglLogname2, NEWNAME = $bmramDB`_log );"
Invoke-Sqlcmd -ServerInstance $primarySvr -Database master -Query "IF ( DB_ID('$bmramDB') IS NOT NULL) ALTER DATABASE $bmramDB SET MULTI_USER"

##############################################################################################################################
#connect to RAMDB #this is bills way of connecting to app database to run scripts against

$applicationDatabaseConnection=$null
$closeAppDBConnection = $false;
if (!$applicationDatabaseConnection) #if no $databaseConnection was passed (e.g. if this script is being run directly), initialize it
{
	$applicationDatabaseConnection = new-object System.Data.SqlClient.SqlConnection;
	$applicationDatabaseConnection = New-SqlConnection -databaseServer $primarySvr ` -databaseAccountLogin $managementDatabaseAccountLogin ` -databaseAccountLoginPassword $managementDatabaseAccountLoginPassword ` -databaseAccountLoginDomain $managementDatabaseAccountLoginDomain ` -database $applicationDatabaseName;
    $closeAppDBConnection = $true;
}
#######################################################################################################################
#verify database exists
$database = $bmramDB
$sql = "SELECT Count(*) DBExists FROM sys.databases WHERE name = '$($database)'";
		Write-Verbose $sql;
        [bool]$databaseExists = (exec-query -databaseConnection $applicationDatabaseConnection -sql $sql -continueOnError $continueOnError)[0].Rows[0].DBExists;
		$Message = "Database $($database) Exists: $($databaseExists)"
        Write-Output $message
        $message | Out-file $logfile -Append
#set to full recovery
$message = " Set $customerID RAMDB Database to FULL recovery model "
Write-Output $message
$message | Out-File $logfile -Append
Invoke-Sqlcmd -ServerInstance $primarySvr -Database master -Query "ALTER DATABASE $bmramDB SET RECOVERY FULL"
#######################################################################################################################
#add new customer to BMRAMControl
$message = " Initialize new Customer in BMRAMControl database "
Write-Output $message
$message | Out-File $logfile -Append
Invoke-Sqlcmd -ServerInstance $listener -Database "BMRAMControl" -Query "EXEC dbo.dba_AddCustomer @CustomerID = '$customerID' "
$message = " Update BMRAMControl with CustomerProps properties "
Write-Output $message
$message | Out-File $logfile -Append
Invoke-Sqlcmd -ServerInstance $listener -Database "BMRAMControl" -Query "EXEC dbo.dba_SetCustomerProperty @CustomerID='$customerID', @Name='ENVIRONMENT_TYPE',       @Value='$environmentType'"
Invoke-Sqlcmd -ServerInstance $listener -Database "BMRAMControl" -Query "EXEC dbo.dba_SetCustomerProperty @CustomerID='$customerID', @Name='CUSTOMER_NAME',          @Value='$customerName'"
Invoke-Sqlcmd -ServerInstance $listener -Database "BMRAMControl" -Query "EXEC dbo.dba_SetCustomerProperty @CustomerID='$customerID', @Name='SERIAL_NUMBER',          @Value='$customerSN'"
Invoke-Sqlcmd -ServerInstance $listener -Database "BMRAMControl" -Query "EXEC dbo.dba_SetCustomerProperty @CustomerID='$customerID', @Name='CLUSTER_NAME',           @Value='$clusterPrefix'"
Invoke-Sqlcmd -ServerInstance $listener -Database "BMRAMControl" -Query "EXEC dbo.dba_SetCustomerProperty @CustomerID='$customerID', @Name='BACKUP_DB',              @Value='OFF'"
Invoke-Sqlcmd -ServerInstance $listener -Database "BMRAMControl" -Query "EXEC dbo.dba_SetCustomerProperty @CustomerID='$customerID', @Name='CUSTOMER_TYPE',          @Value='$customertype'"
#Clear out RESET PASSWORD as NOT USED
Invoke-Sqlcmd -ServerInstance $listener -Database "BMRAMControl" -Query "EXEC dbo.dba_SetCustomerProperty @CustomerID='$customerID', @Name='RESET_PASSWORD',          @Value=''"
#clear out the docmandb entry that is autogenerated since R4 doesn't use docman
Invoke-Sqlcmd -ServerInstance $listener -Database "BMRAMControl" -Query "Update tbldatabases set DocManDBName = '' where customerID = '$customerID' "         
$sql = "USE BMRAMControl; Select * from vwCustomerProps where customerID = '$($customerID)'" 
$message = exec-query -databaseConnection $applicationDatabaseConnection -sql $sql -continueOnError $continueOnError;
Write-Output $message
$message | Out-File $logfile -Append
#######################################################################################################################
#Run the BMRAMControl sync runbook
Select-AzSubscription -Subscription $SubscriptionName -Tenant $azureTenantid
Set-AzContext -Subscription $SubscriptionName
ExecuteRunbookEXEC_BMRAMControl -clusterNamePrefix $clusterPrefixInfo
#######################################################################################################################
#specific to SetupTenant.ps1
#and ConfigureSecurity
$serviceAccountUser = $serviceAccountLogin
$_loginlessuser = $loginlessuser #store it to rerun if failure
#################################
$message ="
*******************************************
Create SQL Logins for Report User Accounts 
      on the primary and secondary
             replicas

SQL Logins (for Reports) = 
         $reportUserLogin
         bmqr\$reportUserLogin
*******************************************"
Write-Output $message 
$message | Out-File $logfile -Append
$message =" Creating the 
  SQL Login (for Reports DataSource) 
        using SQL Authentication:
         
             $reportUserLogin
        
*******************************************"
Write-Output $message 
$message | Out-File $logfile -Append
#create the SQL authentication login
.\CreateSqlServerLogin.ps1 -databaseConnection $applicationDatabaseConnection ` -databaseServer $applicationDatabaseServer -managementDatabaseAccountLogin $managementDatabaseAccountLogin ` -managementDatabaseAccountLoginPassword $managementDatabaseAccountLoginPassword ` -managementDatabaseAccountLoginDomain $managementDatabaseAccountLoginDomain ` -databaseSqlLoginName $reportUserLogin ` -databaseSqlLoginPassword $reportUserLoginPassword ` -disableLogin $false ` -continueOnError $false;
$sql = "
SELECT N'USE Master; CREATE LOGIN ['+sp.[name]+'] WITH PASSWORD=0x'+
       CONVERT(nvarchar(max), l.password_hash, 2)+N' HASHED, CHECK_POLICY=OFF, '+
       N'SID=0x'+CONVERT(nvarchar(max), sp.[sid], 2)+N'; ALTER LOGIN ['+sp.[name]+'] WITH CHECK_EXPIRATION = OFF;' 
FROM master.sys.server_principals AS sp
INNER JOIN master.sys.sql_logins AS l ON sp.[sid]=l.[sid]
WHERE sp.[type]='S' AND sp.is_disabled=0 and sp.name = '$($reportUserLogin)' "
$sql2 = exec-query -databaseConnection $applicationDatabaseConnection -sql $sql -continueOnError $continueOnError;
$sql2 = $sql2.column1 
#connect to secondary SVR
$closeSecConnection = $false
if (!$secondaryDatabaseConnection) 
{   $secondaryDatabaseConnection = new-object System.Data.SqlClient.SqlConnection;
	$secondaryDatabaseConnection = New-SqlConnection -databaseServer $secondarySvr ` -databaseAccountLogin $managementDatabaseAccountLogin ` -databaseAccountLoginPassword $managementDatabaseAccountLoginPassword ` -databaseAccountLoginDomain $managementDatabaseAccountLoginDomain ` -database master;
    $closeSecConnection = $true;
}
exec-query -databaseConnection $secondaryDatabaseConnection -sql $sql2 -continueOnError $continueOnError;
#create the Windows SQL Login
$databaseSqlLoginName = "bmqr\" + $reportUserLogin
$reportuserDomainLogin = $databaseSqlLoginName
$message ="
*******************************************
      Create Domain User in AD
               for the
         $reportuserDomainLogin
               before
     creating the Windows SQL Login
*******************************************"
Write-Output $message 
$message | Out-File $logfile -Append
New-ADUser -SamAccountName $reportUserLogin -name $reportUserLogin -userPrincipalName "$reportUserLogin@bmqr.local" -GivenName $reportUserLogin -Surname $reportUserLogin -DisplayName $reportUserLogin -Path 'CN=Users,DC=bmqr,DC=local' -ChangePasswordAtLogon 0 -PasswordNeverExpires 1 -AccountPassword (ConvertTo-SecureString -AsPlainText $reportUserLoginPassword -Force ) -Enabled $true -server $domainController
sleep 5
$NewADUserExists = Get-ADUser -Filter "Name -eq '$reportUserLogin'" 
if([string]::IsNullOrEmpty($NewADUserExists))
    {
    $message = "Error: Active Directory user: $reportUserLogin was not created! Cancel deployment!"
    Write-Output $message
    $message | Out-File $logfile -Append
    }else
    { 
    $message = "Active Directory user created: $reportUserLogin, press enter to continue at the prompt"
    Write-Output $message

    $message | Out-File $logfile -Append
    $NewADUserExists | Out-File $logfile -Append
    }
$message ="
    Creating the 
    SQL Login (for Reports Browser Role) 
        using Windows Authentication:
      
          $reportuserDomainLogin
******************************************"
Write-Output $message 
$message | Out-File $logfile -Append
#create the sql login for the windows domain user
$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine("USE Master;")
[void]$sb.AppendLine("IF NOT EXISTS (SELECT loginname FROM sys.syslogins WHERE Name = '$($databaseSqlLoginName)')")
[void]$sb.AppendLine("BEGIN")
[void]$sb.AppendLine("	CREATE LOGIN [$($databaseSqlLoginName)] FROM WINDOWS ")
[void]$sb.Append("END;")
$sql = $sb.ToString()
exec-query -databaseConnection $applicationDatabaseConnection -sql $sql -continueOnError $continueOnError;
exec-query -databaseConnection $secondaryDatabaseConnection -sql $sql -continueOnError $continueOnError;
#Invoke-sqlcmd $sql2 -ServerInstance $secondarySvr
if ($closeSecConnection)
{
    $secondaryDatabaseConnection.Close();
}
try { 
     Start-Transcript -path ".\ApplyReportPermissions.txt";

} catch { 
       stop-transcript;
       Start-Transcript -path ".\ApplyReportPermissions.txt";
} 
$ErrorActionPreference = "Stop";
$message ="
    Create database user for Report User Account
         linked to the SQL authentication Login 
             for use on Report Datasource
                   and grant rights
     $bmramDB Report Username = $reportUserLogin
*********************************************************"
Write-Output $message 
$message | Out-File $logfile -Append
$sql = "USE $($bmramDB); IF DATABASE_PRINCIPAL_ID('$($reportUserLogin)') IS NULL CREATE USER [$($reportUserLogin)] FOR LOGIN [$($reportUserLogin)]  EXEC sp_Addrolemember 'db_datareader', [$($reportUserLogin)];";
exec-query -databaseConnection $applicationDatabaseConnection -sql $sql -continueOnError $continueOnError;
$securablesSpreadsheetName = "DatabaseObjectPermissionsForReportUser.csv"
Set-Location $PSScriptRoot;
# Grant report User rights to needed functions 
.\ApplyPermissionsForReportUser.ps1 -databaseConnection $applicationDatabaseConnection ` -databaseServer  $applicationDatabaseServer ` -securablesSpreadsheet $securablesSpreadsheetName ` -spreadsheetPath ".\" ` -reportUserLogin $reportUserLogin ` -continueOnError $continueOnError;
try{
	Stop-Transcript;
	}
Catch
	{
	Write-Host "Host Was Not Transcribing";
	}
#$logfileApplyReportPermissons = "H:\R4Environment\Provisioning\Scripts\ApplyReportPermissions.txt"
$logfileApplyReportPermissons = ".\ApplyReportPermissions.txt"
$logfileApplyReportPermissionsInfo = Import-Csv $logfileApplyReportPermissons
$logfileApplyReportPermissionsInfo | Out-File $logfile -Append
########################################################################################################################
$message ="Create $r4AppUser and loginlessuser users on RAMDB and set security and Change database authorization to RamDatabaseOwner"
Write-Output $message 
$message | Out-File $logfile -Append
$MAINTCounter = "01" #change when rewritten to run in parallel
$logfileDestination = "H:\CustomerDeployments\$customerID" #when running in parallel this will be defined at the top and be written in the Logs folder
.\ConfigureSecurity.ps1 -databaseConnection $applicationDatabaseConnection ` -databaseServer $applicationDatabaseServer ` -databaseName $applicationDatabaseName ` -serviceAccountLogin $serviceAccountLogin ` -serviceAccountLoginDomain $serviceAccountLoginDomain ` -databaseOwnerAccount $databaseOwnerAccount ` -databaseOwnerAccountDomain $databaseOwnerAccountDomain ` -loginlessUser $loginlessUser ` -securablesSpreadsheetName "DatabaseObjectPermissions.csv" ` -databaseRoleSpreadsheetName "DatabaseRoleMemberships.csv" ` -securablesSpreadsheetPath ".\" ` -continueOnError $continueOnError ` -isDevelopmentEnvironment $isDevelopmentEnvironment ` -MAINTCounter $MAINTCounter ` -logfileDestination $logfileDestination  
$txtpath = $logfileDestination + "\ConfigureSecurity_" + $MAINTCounter + "_" + $bmramdb + ".txt"
$logfileConfigSec = $txtpath
$logfileConfigSecInfo = Import-Csv $logfileConfigSec
$logfileConfigSecInfo | Out-File $logfile -Append
##################################################################################################################
#specific to SetupTenant.ps1
try { 
     Start-Transcript -path ".\SetupTenant.txt";
} catch { 

       stop-transcript;
       Start-Transcript -path ".\SetupTenant.txt";
} 
$ErrorActionPreference = "Stop";
$message ="
*************************************
Loading Tenant Configuration
Create Tenant DB Tenants 
and TenantKeys rows
Create Landing TenantConnectionDetails
row
*************************************" 
Write-Output $message 
$message | Out-File $logfile -Append
# format service account
if([string]::IsNullOrEmpty($serviceAccountLoginDomain))
{
	$_serviceAccountLogin = $serviceAccountLogin;
}
	else
{
	$_serviceAccountLogin =  "$($serviceAccountLoginDomain)\$($serviceAccountLogin)";
}
#Change database authorization to the least privlige database owner User
if([string]::IsNullOrEmpty($databaseOwnerAccountDomain))
{# No Domain Supplied must be using Sql Login
	$_databaseOwnerAccount = $databaseOwnerAccount;
}
	else
{
	$_databaseOwnerAccount =  "$($databaseOwnerAccountDomain)\$($databaseOwnerAccount)";
}
$tenantId = ""
if([string]::IsNullOrEmpty($tenantId))
	{
		$tenantId = New-Guid;
		#Create Tenant
		$sql = "USE $($tenantDatabaseName);  INSERT INTO bmqr.Tenants VALUES('$($tenantId)', '$($subdomain)', '$($tenantName)');"
		exec-query -databaseConnection $tenantDatabaseConnection -sql $sql -continueOnError $continueOnError;
        write-output "Created tenantId = $tenantId";
	}
Write-Output "Create tenantKeys.keyid and update tenantkeys"
#Create Tenant Key to store Database Server Name for use in connection string (Listener Name)
$keyId = New-Guid;
$sql = "USE $($tenantDatabaseName); INSERT INTO bmqr.TenantKeys VALUES('$($keyId)', '$($tenantId)', 'ConnectionStringServer', '$($applicationDatabaseServer)');"
exec-query -databaseConnection $tenantDatabaseConnection -sql $sql -continueOnError $continueOnError;
write-output "TenantKeys updated with keyID, tenantID, ConnectionStringServer"
Write-Output "Add the ramapp user and password to TenantKeys"
    #Setup Sql Server credentials 
    $keyId = New-Guid;  #I don't know why we do this again when it was done above
    $sql = "USE $($tenantDatabaseName);`r`nINSERT INTO bmqr.TenantKeys VALUES('$($keyId)', '$($tenantId)', 'PasswordSecretName', '$($serviceAccountLoginPassword)');`r`n";
    $keyId = New-Guid;  #I don't know why we do this again when it was done above
    $sql += "USE $($tenantDatabaseName);INSERT INTO bmqr.TenantKeys VALUES('$($keyId)', '$($tenantId)', 'UserId', '$($serviceAccountLogin)');";
#}
    exec-query -databaseConnection $tenantDatabaseConnection -sql $sql -continueOnError $continueOnError;
    Write-Output "added ramapp and password to TenantKeys"
#Create Tenant Keys to store reporting user credentials
if(![string]::IsNullOrEmpty($reportingUserID))
{
	$keyId = New-Guid;
    $sql = "USE $($tenantDatabaseName);`r`nINSERT INTO bmqr.TenantKeys VALUES('$($keyId)', '$($tenantId)', 'ReportingUserID', '$($reportingUserID.replace("'", "''"))');`r`n";
	exec-query -databaseConnection $tenantDatabaseConnection -sql $sql -continueOnError $continueOnError;
}else{
$message = "ERROR: ReportingUserID variable is null or empty, ReportingUserID TenantKey was not created!"
Write-Output $message 
$message | Out-File $logfile -Append
}

if(![string]::IsNullOrEmpty($reportingUserDomain))
{
	$keyId = New-Guid;
    $sql = "USE $($tenantDatabaseName);`r`nINSERT INTO bmqr.TenantKeys VALUES('$($keyId)', '$($tenantId)', 'ReportingUserDomain', '$($reportingUserDomain.replace("'", "''"))');`r`n";
	exec-query -databaseConnection $tenantDatabaseConnection -sql $sql -continueOnError $continueOnError;
}else{
$message = "ERROR: ReportingUserDomain variable is null or empty, ReportingUserDomain TenantKey was not created!"
Write-Output $message 
$message | Out-File $logfile -Append
}
if(![string]::IsNullOrEmpty($reportingUserPassword))
{
    $keyId = New-Guid;
    $sql = "USE $($tenantDatabaseName);`r`nINSERT INTO bmqr.TenantKeys VALUES('$($keyId)', '$($tenantId)', 'ReportingUserPasswordSecretName', 'ReportUserPassword');`r`n";
	exec-query -databaseConnection $tenantDatabaseConnection -sql $sql -continueOnError $continueOnError;
}else{
$message = "ERROR: reportingUserPassword variable is null or empty, reportingUserPassword TenantKey was not created!"
Write-Output $message 
$message | Out-File $logfile -Append
}
#add the reportserver and reportpath info
if(![string]::IsNullOrEmpty($reportServer))
{
    $keyId = New-Guid;
    $sql = "USE $($tenantDatabaseName);`r`nINSERT INTO bmqr.TenantKeys VALUES('$($keyId)', '$($tenantId)', 'ReportServer', '$($reportServer.replace("'", "''"))');`r`n";
	exec-query -databaseConnection $tenantDatabaseConnection -sql $sql -continueOnError $continueOnError;
}else{
$message = "ERROR: reportServer variable is null or empty, reportServer TenantKey was not created!"
Write-Output $message 
$message | Out-File $logfile -Append
}
if(![string]::IsNullOrEmpty($reportPath))
{
    $keyId = New-Guid;
    $sql = "USE $($tenantDatabaseName);`r`nINSERT INTO bmqr.TenantKeys VALUES('$($keyId)', '$($tenantId)', 'ReportPath', '$($reportPath.replace("'", "''"))');`r`n";
	exec-query -databaseConnection $tenantDatabaseConnection -sql $sql -continueOnError $continueOnError;
}else{
$message = "ERROR: reportPath variable is null or empty, reportPath TenantKey was not created!"
Write-Output $message 
$message | Out-File $logfile -Append
}
#add the app environment caption and background color
if(![string]::IsNullOrEmpty($applicationEnvironment))
{
    $keyId = New-Guid;
    $sql = "USE $($tenantDatabaseName);`r`nINSERT INTO bmqr.TenantKeys VALUES('$($keyId)', '$($tenantId)', 'AppEnvironment', '$($applicationEnvironment.replace("'", "''"))');`r`n";
	exec-query -databaseConnection $tenantDatabaseConnection -sql $sql -continueOnError $continueOnError;
}else{
$message = "ERROR: applicationEnvironment variable is null or empty, applicationEnvironment TenantKey was not created!"
Write-Output $message 
$message | Out-File $logfile -Append
}

if(![string]::IsNullOrEmpty($applicationEnvironmentBackground))
{
    $keyId = New-Guid;
    $sql = "USE $($tenantDatabaseName);`r`nINSERT INTO bmqr.TenantKeys VALUES('$($keyId)', '$($tenantId)', 'AppEnvBackground', '$($applicationEnvironmentBackground.replace("'", "''"))');`r`n";
	exec-query -databaseConnection $tenantDatabaseConnection -sql $sql -continueOnError $continueOnError;
}else{
$message = "ERROR: applicationEnvironmentBackground variable is null or empty, applicationEnvironmentBackground TenantKey was not created!"
Write-Output $message 
$message | Out-File $logfile -Append
}
#Create Tenant Key to store trusted Connection for use in connection string for local deployments
Write-Output "Add the API Key to TenantKeys"
$keyId = New-Guid;  #I don't know why we do this again when it was done above
$sql = "USE $($tenantDatabaseName); INSERT INTO bmqr.TenantKeys VALUES('$($keyId)', '$($tenantId)', 'ApiKey', '$($tenantApiKey.replace("'", "''"))');"
exec-query -databaseConnection $tenantDatabaseConnection -sql $sql -continueOnError $continueOnError;
Write-Output "added apikey to TenantKeys"
#6.2.0 AzureStorageAccountName tenantkey add
Write-Output "Add the AzureStorageAccountName Key to TenantKeys"
$keyId = New-Guid
$sql = "USE $($tenantDatabaseName); INSERT INTO bmqr.TenantKeys VALUES('$($keyId)', '$($tenantId)', 'AzureStorageAccountName', '<Placeholder>');"
exec-query -databaseConnection $tenantDatabaseConnection -sql $sql -continueOnError $continueOnError;
Write-Output "added AzureStorageAccountName to TenantKeys"
#6.2.0 AzureStorageSecretName  tenantkey add
Write-Output "Add the AzureStorageAccountName Key to TenantKeys"
$keyId = New-Guid
$sql = "USE $($tenantDatabaseName); INSERT INTO bmqr.TenantKeys VALUES('$($keyId)', '$($tenantId)', 'AzureStorageSecretName', '<Placeholder>');"
exec-query -databaseConnection $tenantDatabaseConnection -sql $sql -continueOnError $continueOnError;
Write-Output "added AzureStorageSecretName to TenantKeys"
#pull a list of tenantkeys to logfile
$sql = "USE $($tenantDatabaseName); Select * from bmqr.TenantKeys Where Tenantid = '$($tenantId)'"
$message = exec-query -databaseConnection $tenantDatabaseConnection -sql $sql -continueOnError $continueOnError;
Write-Output $message 
$message | Out-File $logfile -Append
#clean up existing Landing entry for application database if it exists
Write-Output "Remove Landing db tenantconnectiondetails row and re-add with updated tenantid"
#commenting out $isdevelopmentenvironment
#if($isDevelopmentEnvironment)
	$sql = "USE $($landingDatabaseName); DELETE FROM bmqr.TenantConnectionDetails WHERE TenantId = '$($tenantId)' OR DatabaseName = '$($applicationDatabaseName)';";
	exec-query -databaseConnection $applicationDatabaseConnection -sql $sql -continueOnError $continueOnError;
    write-output "landing tenantconnectiondetails removed for customer if row previously existed for some reason"
# Add entry to landing database
Write-Output "add the landing tenantconnectiondetails back in with tenantid, RAMDB name, loginlessuser"
$sql = "USE $($landingDatabaseName); INSERT INTO bmqr.TenantConnectionDetails VALUES('$($tenantId)', '$($applicationDatabaseName)', '$($loginlessUser)');"
exec-query -databaseConnection $applicationDatabaseConnection -sql $sql -continueOnError $continueOnError;
write-output "Added tenantconnectiondetails to landing"
# set tenant id and API Key for application database
Write-Output "setting RAMDB registry key values  for $tenantid and $tenantApiKey"
Invoke-Sqlcmd -ServerInstance $listener -Database $applicationDatabaseName -Query "USE $($applicationDatabaseName);EXEC BMRAM.setRegistryKeyValue 'TenantId', '$($tenantId)'" -QueryTimeout 360             
$sql = "USE $($applicationDatabaseName);EXEC BMRAM.setRegistryKeyValue 'ApiKey', '$($tenantApiKey.replace("'", "''"))'"
#Invoke-Sqlcmd -ServerInstance $primarySvr -Database $applicationDatabaseName -Query "EXEC BMRAM.setRegistryKeyValue 'ApiKey', '$($tenantApiKey.replace("'", "''"))'" -QueryTimeout 360
exec-query -databaseConnection $applicationDatabaseConnection -sql $sql -continueOnError $false;


Write-Host "Script has executed at line 1001 and bus configurartion has been started"
# Set Service Bus configuration for tenant
Write-Output "setting service bus config for tenant"
[int]$b = $null #used after as refence
$restClientconfigurationId = New-GUID;
$uriPort = IF(![string]::IsNullOrEmpty($uriPort) -and [int32]::TryParse($uriPort, [ref]$b)) {$uriPort} ELSE {$null};
$uriPath = IF(![string]::IsNullOrEmpty($uriPath)) {$uriPath} ELSE {[system.dbnull]::value};
$uriQuerystring = IF(![string]::IsNullOrEmpty($uriQuerystring)) {$uriQuerystring} ELSE {[system.dbnull]::value};
$uriFragment = IF(![string]::IsNullOrEmpty($uriFragment)) {$uriFragment} ELSE {$null};
$httpVerb = IF(![string]::IsNullOrEmpty($httpVerb)) {$httpVerb} ELSE {[system.dbnull]::value};
$requestHeaders = IF(![string]::IsNullOrEmpty($requestHeaders)) {$requestHeaders} ELSE {[system.dbnull]::value};
$serviceBusNamespace = IF(![string]::IsNullOrEmpty($serviceBusNamespace)) {$serviceBusNamespace} ELSE {[system.dbnull]::value};
$serviceBusTopic = IF(![string]::IsNullOrEmpty($serviceBusTopic)) {$serviceBusTopic} ELSE {[system.dbnull]::value};
$serviceBusAccessPolicy = IF(![string]::IsNullOrEmpty($serviceBusAccessPolicy)) {$serviceBusAccessPolicy} ELSE {[system.dbnull]::value};
$accessPolicyKey = IF(![string]::IsNullOrEmpty($accessPolicyKey)) {$accessPolicyKey} ELSE {[system.dbnull]::value};
$accessTokenLifetime = IF(![string]::IsNullOrEmpty($accessTokenLifetime) -and [int32]::TryParse($accessTokenLifetime, [ref]$b)) {$accessTokenLifetime} ELSE {[system.dbnull]::value};
$batchServiceBusTopic = IF(![string]::IsNullOrEmpty($batchServiceBusTopic)) {$batchServiceBusTopic} ELSE {[system.dbnull]::value};

    $parameters = $null; 
	$parameters = @{restClientconfigurationId=$restClientconfigurationId; uriScheme=$uriScheme; uriHost=$uriHost; uriPort=$uriPort; uriPath=$uriPath; uriQuerystring=$uriQuerystring; uriFragment=$uriFragment; httpVerb=$httpVerb; requestHeaders=$requestHeaders; serviceBusNamespace=$serviceBusNamespace; serviceBusTopic=$serviceBusTopic; serviceBusAccessPolicy=$serviceBusAccessPolicy; accessPolicyKey=$accessPolicyKey; accessTokenLifetime=$accessTokenLifetime; batchServiceBusTopic=$batchServiceBusTopic};

 $sql = "USE $($applicationDatabaseName);
DELETE FROM  BMRAM.RestClientConfigurations;
INSERT INTO BMRAM.RestClientConfigurations
SELECT 	@restClientconfigurationId restClientconfigurationId
		,NULLIF(@uriScheme,'') uriScheme
		,NULLIF(@uriHost,'') uriHost
		,NULLIF(@uriPort,0) uriPort
		,NULLIF(@uriPath,'') uriPath
		,NULLIF(@uriQuerystring,'') uriQuerystring
		,NULLIF(@uriFragment,'') uriFragment
		,NULLIF(@httpVerb,'') httpVerb
		,NULLIF(@requestHeaders,'') requestHeaders
		,NULLIF(@serviceBusNamespace,'') serviceBusNamespace
		,NULLIF(@serviceBusTopic,'') serviceBusTopic
		,NULLIF(@serviceBusAccessPolicy,'') serviceBusAccessPolicy
		,NULLIF(@accessPolicyKey,'') accessPolicyKey
		,NULLIF(@accessTokenLifetime,'') accessTokenLifetime
        ,NULLIF(@batchServiceBusTopic,'') batchServiceBusTopic;";

#Write-Output $parameters
exec-query -databaseConnection $applicationDatabaseConnection -sql $sql -parameters $parameters -continueOnError $true;
#set Service Bus Registry Keys
Write-Output "setting RAMDB registry key values"
exec-query -databaseConnection $applicationDatabaseConnection -sql "USE $($applicationDatabaseName); EXEC BMRAM.setRegistryKeyValue 'DefaultRestClientConfiguration', '$($restClientconfigurationId)'" -continueOnError $continueOnError;
exec-query -databaseConnection $applicationDatabaseConnection -sql "USE $($applicationDatabaseName); EXEC BMRAM.setRegistryKeyValue 'ControlMessageTopic', '$($controlMessageTopic)'" -continueOnError $continueOnError;
#Because we don't know these at provisioning, the second row will match the first row in RestClientConfigurations but the RestClientConfiguraitonID = bmram.cfgRegistry's DefaultIntegrationHandlerConfiguration value
$integrationRestClientConfigurationId = New-GUID;
$integrationServiceBusNamespace = IF(![string]::IsNullOrEmpty($integrationServiceBusNamespace)) {$integrationServiceBusNamespace} ELSE {$serviceBusNamespace};
$integrationUriHost = IF(![string]::IsNullOrEmpty($integrationUriHost)) {$integrationUriHost} ELSE {$urihost};
$integrationAccessPolicyKey = IF(![string]::IsNullOrEmpty($integrationAccessPolicyKey)) {$integrationAccessPolicyKey} ELSE {$accessPolicyKey};
# Set Service Bus configuration for service bus integrations 
$parameters = $null;
$parameters = @{restClientconfigurationId=$restClientconfigurationId; integrationRestClientconfigurationId=$integrationRestClientconfigurationId; integrationServiceBusNamespace=$integrationServiceBusNamespace; integrationUriHost=$integrationUriHost; integrationAccessPolicyKey=$integrationAccessPolicyKey};
$sql = "
INSERT INTO BMRAM.RestClientConfigurations
SELECT 	@integrationRestClientConfigurationId restClientconfigurationId
		,uriScheme
		,NULLIF(@integrationUriHost,'') urihost
		,uriPort
		,uriPath
		,uriQuerystring
		,uriFragment
		,httpVerb
		,requestHeaders
		,NULLIF(@integrationServiceBusNamespace,'') serviceBusNamespace
		,NULL
		,serviceBusAccessPolicy
		,NULLIF(@integrationAccessPolicyKey,'') accessPolicyKey
		,accessTokenLifetime
		,NULL
FROM	BMRAM.RestClientConfigurations 
WHERE	RestClientConfigurationID = @restClientconfigurationId;";
exec-query -databaseConnection $applicationDatabaseConnection -sql $sql -parameters $parameters -continueOnError $true;
#set Service Bus Registry Keys
exec-query -databaseConnection $applicationDatabaseConnection -sql "USE $($applicationDatabaseName); EXEC BMRAM.setRegistryKeyValue 'DefaultIntegrationHandlerConfiguration', '$($integrationRestClientconfigurationId)'" -continueOnError $continueOnError;
try{
	Stop-Transcript;
	}
Catch
	{
	Write-Host "Host Was Not Transcribing";
	}
#$logfileSetupTenant = "H:\R4Environment\Provisioning\Scripts\SetupTenant.txt"
$logfileSetupTenant = ".\SetupTenant.txt"
$logfileSetupTenantInfo = Import-Csv $logfileSetupTenant
$logfileSetupTenantInfo | Out-File $logfile -Append
#################################
write-output "tenantId = $tenantId";
$message = "Finding the configurationAuditReportId to update the registry"
Write-Output $message
$message | Out-File $logfile -Append
$sql = "USE $($applicationDatabaseName); SELECT MemberId FROM SYSTEM.ADMIN_REPORT WHERE ID = 'bpt_AdminSystemConfigurationLog' AND SetName = 'SYSTEM';"
$configurationAuditReportId = exec-query -databaseConnection $applicationDatabaseConnection -sql $sql -continueOnError $continueOnError;
$configurationAuditReportId = $configurationAuditReportId.MemberID
$message = "configurationAuditReportId = $configurationAuditReportId "
Write-Output $message
$message | Out-File $logfile -Append
$message = "set registry values in RAMDB running Set-RegistryValues.ps1"
Write-Output $message
$message | Out-File $logfile -Append
.\Set-RegistryValues.ps1	-databaseConnection $applicationDatabaseConnection ` -databaseServer $applicationDatabaseServer ` -databaseName $applicationDatabaseName ` -systemBuildMode $systemBuildMode ` -serverUrl $serverUrl ` -recordsPerPage $recordsPerPage ` -configurationAuditReportId $configurationAuditReportId ` -databaseMailProfile $environmentType ` -requestOnlyWorkspaceID $requestOnlyWorkspaceID ` -systemConfigurationAccess $systemConfigurationAccess; #-managementDatabaseAccountLogin $managementDatabaseAccountLogin ` -managementDatabaseAccountLoginPassword $managementDatabaseAccountLoginPassword `
$sql = "USE $($applicationDatabaseName); Select * from BMRAM.cfgRegistry" 
$message = exec-query -databaseConnection $applicationDatabaseConnection -sql $sql -continueOnError $continueOnError;
Write-Output $message
$message | Out-File $logfile -Append
$logfileSetReg = ".\SetRegistryValues.txt"
$logfileSetupRegInfo = Import-Csv $logfileSetReg
$logfileSetupRegInfo | Out-File $logfile -Append
######################################################################################################################
#add user for CLR Assembly if it doesn't exist
Set-Location $PSScriptRoot;
cd $PSScriptRoot;
Import-Module -Name .\exec-sqlfile.ps1 -Force;
$clrAssemblyLogin = "ClrRestClientAssemblyLogin"
$clrAssemblyUser = "ClrRestClientAssemblyUser"
$clrAssemblyPersmissionLevel = 'UNSAFE'; 
$clrAssemblyName ="ClrRestClient";
$clrAssemblyBinaryPath = ".\Assemblies\ClrRestClient\Assembly\bin\Release\ClrRestClient.dll"
$sqlroutinesPath = ".\Assemblies\ClrRestClient"
$assemblySqlRoutinesFolderName = "SqlRoutines";
[bool]$continueOnError=$true
$compileDll = $false;
#check for user existenance
$sql = "USE [$($bmramdb)];select Count(*) UserExists from sys.database_principals where name = 'ClrRestClientAssemblyUser'"
[bool]$UserExists = (exec-query -databaseConnection $applicationdatabaseConnection -sql $sql -continueOnError $continueOnError)[0].Rows[0].UserExists;
$message =  "User ($($clrAssemblyUser)) Exists: $($UserExists)";
Write-Output $message
$message | Out-File $logfile -Append
#if it doesn't exist create the user and the assembly
if(!$UserExists){
$sql = @"
CREATE USER [$($clrAssemblyUser)] FOR LOGIN [$($clrAssemblyLogin)];
CREATE ASSEMBLY [$($clrAssemblyName)]
  FROM '$($clrAssemblyBinaryPath)'
  WITH PERMISSION_SET = $($clrAssemblyPersmissionLevel);
"@;
exec-query -databaseConnection $applicationDatabaseConnection  -sql $sql -continueOnError $continueOnError;
#for logfile
  $sql = "USE [$($bmramdb)];select Count(*) UserExists from sys.database_principals where name = 'ClrRestClientAssemblyUser'"
  [bool]$UserExists = (exec-query -databaseConnection $applicationdatabaseConnection -sql $sql -continueOnError $continueOnError)[0].Rows[0].UserExists;
  $message =  "User ($($clrAssemblyUser)) Exists: $($certExists)";
  Write-Output $message
  $message | Out-File $logfile -Append
# if creating the user will go ahead and Compile SQL Routines if routine folder is specified
$message =  "Compiling Assembly Sql Routines in $($assemblySqlRoutinesFolderName)";
Write-Output $message
  $message | Out-File $logfile -Append
if(![String]::IsNullOrEmpty($assemblySqlRoutinesFolderName))
	{
		Join-Path -Path $sqlroutinesPath -ChildPath $assemblySqlRoutinesFolderName | Push-Location;
		Get-ChildItem | where {!$_.PSIsContainer} | ForEach-Object {
			exec-sqlfile -filePath $_.FullName -databaseConnection $applicationDatabaseConnection -continueOnError $continueOnError;
		}
    }
  }
#######################################################################################################################
Set-Location $PSScriptRoot;
cd $PSScriptRoot;
$message = "Set DBMailCertificate on RAMDB"
Write-Output $message
$message | Out-File $logfile -Append
$certificateName = "DBMailCertificate";
$certificateFileName = "$($certificateName).cer";
$privateKeyFileName = "$($certificateName).pvk";
$certificateDrive = $env:SYS_CONFIG;
$certificateFolderPath = "AutomationScripts\Certificate\DatabaseMail\";
$sendgridCertSecret = "SendGridCertPassword"
$certificatePassword = (Get-AzKeyVaultSecret -VaultName $vaultName -Name $sendgridCertSecret).SecretValue
$certificatePassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($certificatePassword)) 
$certificateLocation = $null;
$certificateLocation = Join-Path -Path $certificateDrive -ChildPath $certificateFolderPath;
$signaturePassword = $null;
$targetDatabases = $bmramdb
$routinesToSign = "BMRAM.sendToEmail";
[bool]$continueOnError=$False
#look for a certificate with the same name as the one about to be added
 $sql = "USE [$($targetdatabases)]; SELECT Count(*) CertExists FROM sys.certificates WHERE name = '$($certificateName.replace("'", "''"))'";
 Write-Verbose $sql;
[bool]$certExists = (exec-query -databaseConnection $applicationdatabaseConnection -sql $sql -continueOnError $continueOnError)[0].Rows[0].CertExists;
$message =  "Certificate ($($certificateName)) Exists: $($certExists)";
Write-Output $message
$message | Out-File $logfile -Append
if($certExists){
		#gather the list of objects currently signed by the certificate
$sql = @"
USE [$($targetdatabases)];
SELECT bmram.qryBuildSqlName(SCHEMA_NAME(so.[schema_id]),so.[name]) AS [ObjectName]
FROM sys.crypt_properties scp
INNER JOIN sys.objects so
        ON so.[object_id] = scp.[major_id]
LEFT JOIN sys.certificates sc
        ON sc.thumbprint = scp.thumbprint
LEFT JOIN sys.asymmetric_keys sak
        ON sak.thumbprint = scp.thumbprint
WHERE   so.[type] <> 'U'
AND ISNULL(sc.[name], sak.[name]) = '$($certificateName.replace("'", "''"))'
"@;
			Write-Verbose $sql;
			$signedObjects = (exec-query -databaseConnection $applicationdatabaseConnection -sql $sql -continueOnError $continueOnError);
			foreach($object in $signedObjects)
				     {
								#remove the signature from the objects currently signed by the Certificate being replaced
								$sql = "USE [$($targetdatabases)]; DROP SIGNATURE FROM OBJECT::$($object.ObjectName) BY CERTIFICATE [$($certificateName)]";
								Write-Verbose $sql;
								(exec-query -databaseConnection $applicationdatabaseConnection -sql $sql -continueOnError $continueOnError);
                        }
                  }
             $message = "Routines to Sign:`r`n$($routinesToSign)"
             Write-Output $message
             $message | Out-File $logfile -Append
			 $message = "Signed Objects:`r`n$($signedObjects)"
             Write-Output $message
             $message | Out-File $logfile -Append
			 #conflate distinct specified objects and discovered objects into an array
		     $_routinesToSign = $null;
			 $_routinesToSign = ($routinesToSign, (($signedObjects |Select -ExpandProperty ObjectName) -join ", ") -join ", ").replace("[", "").replace("]", "").split(",").Trim() | Select -unique;
  		#Add The Certificate to the RAMDB database
            $sql = @"
USE $($targetdatabases);
--remove Signature if one by this name already exists;
IF EXISTS (SELECT * FROM sys.certificates WHERE name = '$($certificateName.replace("'", "''"))') DROP CERTIFICATE [$($certificateName)];
--Create Certificate in Tenant's RAM Database
CREATE CERTIFICATE [$($certificateName)]
FROM FILE = '$(Join-Path -Path $certificateLocation -ChildPath $certificateFileName)'
WITH PRIVATE KEY (
FILE = '$(Join-Path -Path $certificateLocation -ChildPath $privateKeyFileName)',
ENCRYPTION BY PASSWORD = '$($certificatePassword.replace("'", "''"))',
DECRYPTION BY PASSWORD = '$($certificatePassword.replace("'", "''"))');
"@
				Write-Verbose $sql;
				exec-query -databaseConnection $applicationdatabaseConnection -sql $sql -continueOnError $continueOnError;	
				$message =  "Routines to sign: `r`n$($_routinesToSign)";
                Write-Output $message
                $message | Out-File $logfile -Append
				# add signature to specified routines
				foreach($routine in $_routinesToSign)
					{
						if(-not([string]::IsNullOrEmpty($routine)))
							{
								#format objectname to make it safe for sql
								$_routine = $routine.replace("[", "").replace("]", "");
								$_routine = "[$($routine.Replace(".", "].["))]"
								#remove the signature from the objects currently signed by the Certificate being replaced
								$sql = "USE [$($targetdatabases)]; ADD SIGNATURE TO OBJECT::$($_routine) BY CERTIFICATE [$($certificateName)] WITH PASSWORD = '$($certificatePassword.replace("'", "''"))';";
								Write-Verbose $sql
								(exec-query -databaseConnection $applicationdatabaseConnection -sql $sql -continueOnError $continueOnError);
							}						
					}
#for logfile:
Write-Host "Script has executed at line 1250 and log file is generated"
$sql = "USE [$($targetdatabases)]; SELECT Count(*) CertExists FROM sys.certificates WHERE name = '$($certificateName.replace("'", "''"))'";
 Write-Verbose $sql;
[bool]$certExists = (exec-query -databaseConnection $applicationdatabaseConnection -sql $sql -continueOnError $continueOnError)[0].Rows[0].CertExists;
$message =  "Certificate ($($certificateName)) Exists: $($certExists), Routines Signed";
Write-Output $message
$message | Out-File $logfile -Append
$sql = @"
USE [$($targetdatabases)];
SELECT bmram.qryBuildSqlName(SCHEMA_NAME(so.[schema_id]),so.[name]) AS [ObjectName]
FROM sys.crypt_properties scp
INNER JOIN sys.objects so
        ON so.[object_id] = scp.[major_id]
LEFT JOIN sys.certificates sc
        ON sc.thumbprint = scp.thumbprint
LEFT JOIN sys.asymmetric_keys sak
        ON sak.thumbprint = scp.thumbprint
WHERE   so.[type] <> 'U'
AND ISNULL(sc.[name], sak.[name]) = '$($certificateName.replace("'", "''"))'
"@;
			Write-Verbose $sql;
            $message = "Signed Objects:"
			$signedObjects = (exec-query -databaseConnection $applicationdatabaseConnection -sql $sql -continueOnError $continueOnError); 
           
            Write-Output $message $signedObjects
            $message | Out-File $logfile -Append
            $signedObjects | Out-File $logfile -Append
  #Take this section out when we go to production
 #Send a Test Email
$mailLoginName = "DBMailLogin"
$testEmailToAccount = $BMQRAdminUser  #credential from above (this will come to the email address of the user doing the customer deployment)
$emailProfile  = $environmenttype
$testEmailSubject = "Applied Signature Test Email for $bmramdb ";
$testEmailBody = "This email is a test email for customer: $customerID.`r`nThe SendToEmail procedure was signed with Signature $($certificateName) associated with Login $($mailLoginName). `r`nEmail is working!"
                $_testEmailSubject = [string]::Format($testEmailSubject,$bmramdb);
				$_testEmailBody = [string]::Format($testEmailBody,$bmramdb);
				$sql = @"
USE $($bmramdb);  
DECLARE
	@mailFormatID		UNIQUEIDENTIFIER
	,@importanceID		UNIQUEIDENTIFIER

DECLARE @mailItemID	INT;
DECLARE @mailFormat			NVARCHAR(128) = 'TEXT',
		@importance			NVARCHAR(6) = 'Normal';	
SELECT @mailFormatID  = MemberID FROM system.MAILFORMAT WHERE Name  = @mailFormat;
SELECT @importanceID = MemberID FROM system.MAILIMPORTANCE WHERE Name = @importance;
--send a test email Tenant's RAM database
EXECUTE BMRAM.sendToEmail '$($emailProfile)','$($testEmailToAccount)', NULL, '$($_testEmailSubject)', '$($_testEmailBody)', @mailFormatID, @importanceID, 0;
"@;
				#Write-Verbose $sql;
				exec-query -databaseConnection $applicationdatabaseConnection -sql $sql -continueOnError $continueOnError;
  	    $message = "Check your email to verify you received a Test Email"
            Write-Output $message 
            $message | Out-File $logfile -Append
#######################################################################################################################
#find ossids for BMQRADmin and BMQRPM
$message = " Finding OSSIDs for BMQRAdmin and BMQRPM user access "
Write-Output $message
$message | Out-File $logfile -Append
 $authHeader = 
@{
    "Content-Type" = "application/json"
    "Authorization" = "Bearer " + $auth0InstallationApiToken
}
$users = @()
$pagecount = 0
while($pagecount -ge 0) {
$auth0URI = "https://$auth0Tenant/api/v2/users?q=identities.connection%3A%22" + $auth0ConnectionName + "%22&page=$pagecount&per_page=50&search_engine=v3"
#$auth0URI ="https://$auth0Tenant/api/v2/users?connection=" + $auth0ConnectionName + "&page=$pagecount&per_page=50&search_engine=v3"
$response = Invoke-RestMethod -Uri $auth0URI -Headers $authHeader -Method GET -TimeoutSec 360
$users +=  $response
$pagecount
$response.Count
$pagecount += 1
if($response.Count -eq 0) {break}
}
foreach($user in $users){
  if($user.upn -eq $BMQRAdminUser){$BMQRAdminOSSID = $user.user_id}
  if($user.upn -eq $BMQRPMUser){$BMQRPMOSSID = $user.user_id}}
$bmqradminInfo = "BMQRAdmin will use " + $BMQRAdminUser + " OSSID = " + $BMQRAdminOSSID  
$bmqrPMInfo = "BMQRPM will use " + $BMQRPMUser + " OSSID = " + $BMQRPMOSSID
$message =
"
$bmqradminInfo
$bmqrPMInfo
"
Write-Output $message
$message | Out-File $logfile -Append    
#######################################################################################################################
#create our auth source
$message = "Create our CLOUD AUTHENTICATION Auth Source
Auth0 App ID = $clientID, Auth0 connection = $auth0ConnectionName "
Write-Output $message
$message | Out-File $logfile -Append  
.\AddAuthenticationSource.ps1 -databaseConnection $applicationDatabaseConnection ` -BMQRAuthenticationSourceID $BMQRAuthenticationSourceID ` -BMQRAuthenticationSourceName $BMQRAuthenticationSourceName ` -authenticationType $authenticationType ` -remoteAccessRegistry $remoteAccessRegistry ` -connectionID $auth0connectionName ` -clientID $clientID ` -domain $auth0tenant ` -authenticationPropertyMapsToAdd $authenticationPropertyMapsToAdd
$sql = "USE $($applicationDatabaseName); Select * from system.ADMIN_AUTHSOURCES where ID = '$($BMQRAuthenticationSourceID)'" 
$message = exec-query -databaseConnection $applicationDatabaseConnection -sql $sql -continueOnError $continueOnError;
Write-Output $message
$message | Out-File $logfile -Append
#######################################################################################################################                                
#create customer auth source
$message = "Create $customerID CLOUD AUTHENTICATION Auth Source"
Write-Output $message
$message | Out-File $logfile -Append  
.\AddAuthenticationSource.ps1 -databaseConnection $applicationDatabaseConnection ` -BMQRAuthenticationSourceID $CustomerAuthenticationSourceID ` -BMQRAuthenticationSourceName $CustomerAuthenticationSourceName ` -authenticationType $authenticationType ` -remoteAccessRegistry $remoteAccessRegistryCustomer ` -clientID $clientID ` -domain $auth0tenant
$sql = "USE $($applicationDatabaseName); Select * from system.ADMIN_AUTHSOURCES where ID = '$($CustomerAuthenticationSourceID)'" 
$message = exec-query -databaseConnection $applicationDatabaseConnection -sql $sql -continueOnError $continueOnError;
Write-Output $message
$message | Out-File $logfile -Append                         
######################################################################################################################
#inactivate any existing auth sources that are not AuthCloud so they don't show
$message = "Inactivate Non-AuthCloud Auth Sources"
$sql = "USE $($applicationDatabaseName); UPDATE system.ADMIN_AUTHSOURCES SET IsActive = 0 where AuthenticationType != 'AUTHCLOUD'" 
exec-query -databaseConnection $applicationDatabaseConnection -sql $sql -continueOnError $continueOnError;
Write-Output $message
$message | Out-File $logfile -Append
#######################################################################################################################
#create personnel records
$message = " Create BMQRAdmin, BMQRPM, BMQRAnalysts personnel in BMRAM "
Write-Output $message
$message | Out-File $logfile -Append
#Verify creation ...select PersonID,* from system.PERSONNEL order by ID
.\AddPersonnel.ps1 -databaseConnection $applicationDatabaseConnection ` -BMQRPersonnelID $BMQRPersonnelID ` -BMQRPersonnelName $BMQRPersonnelName ` -BMQRPersonnelInitialWorkspaceID $BMQRPersonnelInitialWorkspaceID ` -BMQRPersonnelScopeID $BMQRPersonnelScopeID ` -BMQRPersonnelFirstName $BMQRPersonnelFirstName ` -BMQRPersonnelLastName $BMQRPersonnelLastName ` -groupMemberships $groupMemberships
.\AddPersonnel.ps1 -databaseConnection $applicationDatabaseConnection ` -BMQRPersonnelID $BMQRPMPersonnelID ` -BMQRPersonnelName $BMQRPMPersonnelName -BMQRPersonnelInitialWorkspaceID $BMQRPersonnelInitialWorkspaceID ` -BMQRPersonnelScopeID $BMQRPersonnelScopeID ` -BMQRPersonnelFirstName $BMQRPMPersonnelFirstName ` -BMQRPersonnelLastName $BMQRPMPersonnelLastName ` -groupMemberships $groupMemberships
.\AddPersonnel.ps1 -databaseConnection $applicationDatabaseConnection ` -BMQRPersonnelID $BMQRAnalystPersonnelID ` -BMQRPersonnelName $BMQRAnalystPersonnelName -BMQRPersonnelInitialWorkspaceID $BMQRPersonnelInitialWorkspaceID ` -BMQRPersonnelScopeID $BMQRPersonnelScopeID ` -BMQRPersonnelFirstName $BMQRAnalystPersonnelFirstName ` -BMQRPersonnelLastName $BMQRAnalystPersonnelLastName ` -groupMemberships $groupMemberships
.\AddPersonnel.ps1 -databaseConnection $applicationDatabaseConnection ` -BMQRPersonnelID $BMQRAnalyst2PersonnelID ` -BMQRPersonnelName $BMQRAnalyst2PersonnelName -BMQRPersonnelInitialWorkspaceID $BMQRPersonnelInitialWorkspaceID ` -BMQRPersonnelScopeID $BMQRPersonnelScopeID ` -BMQRPersonnelFirstName $BMQRAnalyst2PersonnelFirstName ` -BMQRPersonnelLastName $BMQRAnalyst2PersonnelLastName ` -groupMemberships $groupMemberships
.\AddPersonnel.ps1 -databaseConnection $applicationDatabaseConnection ` -BMQRPersonnelID $BMQRAnalyst3PersonnelID ` -BMQRPersonnelName $BMQRAnalyst3PersonnelName -BMQRPersonnelInitialWorkspaceID $BMQRPersonnelInitialWorkspaceID ` -BMQRPersonnelScopeID $BMQRPersonnelScopeID ` -BMQRPersonnelFirstName $BMQRAnalyst3PersonnelFirstName ` -BMQRPersonnelLastName $BMQRAnalyst3PersonnelLastName ` -groupMemberships $groupMemberships
$sql = "USE $($applicationDatabaseName); select memberid, id, name,entityname from system.RTPERSONNEL where id like 'bmqr%'" 
$message = exec-query -databaseConnection $applicationDatabaseConnection -sql $sql -continueOnError $continueOnError;
Write-Output $message
$message | Out-File $logfile -Append 
###################################################################################################################################
#Set the broker on ramdb
 $message = "Enable Broker on RAMDB"
Write-Output $message
$message | Out-File $logfile -Append
$sql = "USE MASTER;`r`nALTER DATABASE $($applicationDatabaseName) SET NEW_BROKER WITH ROLLBACK IMMEDIATE;`r`nALTER DATABASE $($applicationDatabaseName) SET ENABLE_BROKER;";
Write-Output $sql;
exec-query -databaseConnection $applicationDatabaseConnection -sql $sql -continueOnError $continueOnError;
#######################################################################################################################
###Temporary in the development environment. The ASE cannot access the vm by machine name must use IP for the connection string server.
#ToDo: figure out the way to refer to the database server from the ASE without referencing the IP address as the connection string server, or remove DHCP IP assignment so we can assure the IP won't change
$sql = @"
USE $($tenantDatabaseName);
DECLARE @subdomain nvarchar(128) = '$($subdomain)';
DECLARE @connectionStringServer nvarchar(255) = '$($connectionStringServerIp)';
UPDATE K
SET Value = @connectionStringServer
FROM		bmqr.Tenants	T
INNER JOIN	bmqr.TenantKeys	K	ON T.TenantId = K.TenantId
WHERE	[T].[subdomain] = @subdomain
	AND	[K].[Key] = 'ConnectionStringServer';
"@;
Write-Output $sql;
exec-query -databaseConnection $tenantDatabaseConnection -sql $sql -continueOnError $continueOnError;
#########################################################################################################################
#set RAMDB compatibility level to 150
$sql = @"
USE master
IF  (SELECT substring(ProductVersion, 1, CHARINDEX('.', ProductVersion, 1) - 1) Version
	FROM (SELECT cast(SERVERPROPERTY('ProductVersion') as nvarchar(100)) ProductVersion) D) >= 15
AND (SELECT compatibility_level FROM sys.databases WHERE name = '$($applicationDatabaseName)') < 150
BEGIN
	ALTER DATABASE $($applicationDatabaseName) SET compatibility_level = 150
END;
"@
Write-Output $sql;
exec-query -databaseConnection $applicationDatabaseConnection -sql $sql -continueOnError $continueOnError;
#######################################################################################################################
#set RAMDB  is_parameterization_forced = 1 if =0
$sql = @"
USE master
IF EXISTS	(
			SELECT 1
			FROM sys.databases AS d
			WHERE d.is_parameterization_forced = 0
			AND d.database_id = DB_ID('$($applicationDatabaseName)')
			)
BEGIN
	ALTER DATABASE $($applicationDatabaseName) SET PARAMETERIZATION FORCED;
END;
"@
Write-Output $sql;
exec-query -databaseConnection $applicationDatabaseConnection -sql $sql -continueOnError $continueOnError;
##############################################################################################################################
#DEPLOY REPORTS
if($deploymentMode -eq "BPT"){
 $message =
"
DEPLOYING REPORTS
$reportpath1
$URL
"
Write-Output $message
$message | Out-File $logfile -Append
$message = "
Report Project Name:    R4BPTemplate, R4BPTConfigurationVerification
DataSource:             BMRAMDS
Datasets:               QueryKeys, PrintSessionInfo
"
Write-Output $message
$message | Out-File $logfile -Append
$reportSrcRoot = $deployReportSourceDir
$reportDestRoot = $deployReportDir
$reportSrcPath = $reportSrcRoot #H:\deploymentsource\versionfolder\reports
$reportDestPath = Join-Path -Path $reportDestRoot -ChildPath $customerID | Join-Path -ChildPath "ReportDeployments"#H:\customerdeployments\customer\reportdeployments
$message = "Copying report files to H:\CustomerDeployments\$customerID\ReportDeployments...this takes a few minutes
"
Write-Output $message
$message | Out-File $logfile -Append
# Copy report files to customer deployment directory
if ((Test-Path $reportDestPath))
{
    Remove-Item $reportDestPath -Recurse -Force
}
Copy-Item $reportSrcPath $reportDestPath -Recurse
#Read the report project file, get the datasource, dataset, image, and reports and feed to sub scripts
$reportFilePath = Join-Path -Path $reportDestPath -ChildPath "\R4BPTemplate\R4BPTemplate.rptproj"
$CONFIGreportFilePath = Join-Path -Path $reportDestPath -ChildPath "\R4BPTConfigurationVerification\ConfigurationVerification.rptproj" #R4BPTConfigurationVerification
$reportFile = (Get-Content $reportFilePath) -as [Xml] 
$CONFIGreportFile = (Get-Content $CONFIGreportFilePath) -as [Xml] 
#$OutFileLoc = $reportDestPath
$OutFileDS = $reportDestPath + "\" + "datasourceslist.txt"
$OutfileDatasets = $reportDestPath + "\" + "datasetslist.txt"
$OutfileImages = $reportDestPath + "\" + "imageslist.txt"
$OutfileReports = $reportDestPath + "\" + "reportlist.txt"
$CONFIGOutFileDS = $reportDestPath + "\" + "CONFIGdatasourceslist.txt"
$CONFIGOutfileDatasets = $reportDestPath + "\" + "CONFIGdatasetslist.txt"
$CONFIGOutfileImages = $reportDestPath + "\" + "CONFIGimageslist.txt"
$CONFIGOutfileReports = $reportDestPath + "\" + "CONFIGreportlist.txt"
#get Datasource
$includeDataSources = $reportFile.Project.ItemGroup.Datasource.Include 
$includeDataSources | Out-File $OutFileDS
$message = "
Info read from report project file:
DataSource to deploy:
$includeDataSources "
Write-Output $message
$message | Out-File $logfile -Append
#get Datasets
$includeDatasets = $reportFile.Project.ItemGroup.Dataset.Include
$includeDatasets | Out-File $OutfileDatasets
$message =" Datasets to deploy: $includeDatasets"
Write-Output $message
$message | Out-File $logfile -Append
#get images
$includeImages = ""
$includeImages = $reportFile.Project.ItemGroup.Report
$includeImages2 = $includeImages | where-object {$_.Include -like "*.jpg"} | Select-Object Include, MimeType
#$includeImages3 = $includeImages | where-object {$_.Include -notlike "*.rdl"} | Select-Object Include
#$includeImages3 = $includeImages3.Include
#$includeImages3 = Export-Csv -InputObject $includeImages2 -NoTypeInformation
#$includeImages2 = $includeImages2 | Where-Object { $_.Include -ne "" } | Out-File $OutfileImages -Encoding utf8
#$includeImages2 | Out-File $OutfileImages -Encoding utf8
$includeImages2 | Export-Csv -Path $OutfileImages -NoTypeInformation -Encoding UTF8
$CONFIGincludeImages = ""
$CONFIGincludeImages = $CONFIGreportFile.Project.ItemGroup.Report
$CONFIGincludeImages2 = $CONFIGincludeImages | where-object {$_.Include -notlike "*.rdl"} | Select-Object Include
$CONFIGincludeImages2 = $CONFIGincludeImages2.Include
$message =" 
R4BPTemplate Images to deploy:
$includeImages2
R4BPTConfigurationVerification Images to deploy:
$CONFIGincludeImages2
"
Write-Output $message
$message | Out-File $logfile -Append
#get Reports
$includeReports = $reportFile.Project.Itemgroup.Report.Include
$includeReports | Out-File $OutfileReports
$CONFIGincludeReports = $CONFIGreportFile.Project.Itemgroup.Report.Include
$CONFIGincludeReports | Out-File $CONFIGOutfileReports
$message ="
R4BPTemplate Reports to deploy:
$includeReports
R4BPTConfigurationVerification Reports to deploy:
$CONFIGincludeReports
"
Write-Output $message
$message | Out-File $logfile -Append
#deploy R4BPTemplate project
./DeployReportsForR4.ps1  -customer $customerID -customerPassword $reportUserLoginPassword -reportSrcRoot $deployReportSourceDir ` -reportDestRoot $deployReportDir ` -targetServerUrl $targetRptSvrURL ` -listenerName $listener ` -deployTemplateReports $false ` -deploymentMode $deploymentMode ` -dataSourceUserName $reportUserLogin #-includeDataSources $includeDataSources ` -includeDatasets $includeDatasets ` -includeImages $includeImages3 ` -includeReports $includeReports
##########################################################################################
#deploy R4BPTConfigurationVerification project
Write-Host "Script has executed at line 1536 R4 project started"

Import-Module ReportingServicesTools
$RSConfig = Get-RsDeploymentConfig –RsProjectFile $CONFIGreportFilePath –ConfigurationToUse Debug
$RSConfig.OverwriteDatasets = $false
$RSConfig.OverwriteDataSources = $false
$RSConfig.TargetReportFolder = "$customerID/R4BPTemplate/R4BPTConfigurationVerification"
$RSConfig.TargetDatasetFolder = "$customerID/R4BPTemplate/Datasets"
$RSConfig.TargetDatasourceFolder = "$customerID/Data Sources"
$RSConfig.TargetServerURL = "http://$primarySvr/reportserver"
$ReportPortal = "http://$primarySvr/reports"
$RSConfig | Add-Member –PassThru –MemberType NoteProperty –Name ReportPortal –Value $ReportPortal 
$RSConfig | Publish-RsProject
"publish R4BPTConfigurationVerification images"
#publish images for R4BPTConfigurationVerification
foreach($CONFIGincludeImage in $CONFIGincludeImages2){
$jpgLOC = "H:\CustomerDeployments\$customerID\ReportDeployments\R4BPTConfigurationVerification\$CONFIGincludeImage"
$RsFolder = "/" + $RSConfig.TargetReportFolder           
Write-RsCatalogItem -ReportServerUri $RSConfig.TargetServerURL -RsFolder $RsFolder -Path $jpgLoc -OverWrite -Verbose
}
#get Reports
$message ="Reports deployed!"
Write-Output $message
$message | Out-File $logfile -Append
}
#######################################################################################################################
#set license
$sql = 
"USE $($applicationDatabaseName); select bmram.fn_GetLicenses(default) AS NumberofUsers, bmram.fn_IsNamedUserLicense (default) AS ""LicenseType (0=Concurrent,1=Named)"", 
bmram.fn_GetLicenses('RequestOnly') AS NumberOfRequestOnlyUsers, bmram.fn_GetLicenses('MOBILEAPP') AS NumberOfRAMMobileUsers, bmram.fn_IsAPIEnabled(null) AS ""API (1 = Enabled, 0 = Disabled)"",
bmram.fn_IsMultiSite(null) AS ""1 = Multi-Site, 0 = Single-Site"""
$licenseinfo = (exec-query -databaseConnection $applicationdatabaseConnection -sql $sql -continueOnError $true) 
Write-Output $licenseinfo 
$licenseinfo | Out-File $logfile -Append
 $message =
"
***************************************
Review the Current License info above!
***************************************
"
Write-Output $message
$message | Out-File $logfile -Append
$message =
"
***************************************
Next we will set the license for the 
what the customer purchased...
***************************************
"
Write-Output $message
$message | Out-File $logfile -Append
#$sql = "USE $($tenantDatabaseName); select tenantID from tenant.bmqr.Tenants where Subdomain = '$customerID'"
#$tenantID = (exec-query -databaseConnection $tenantDatabaseConnection -sql $sql -continueOnError $continueOnError).tenantID.Guid;
Set-Location $PSScriptRoot;
$lock = (New-Guid).Guid
if($isProduction -eq "1"){
$numberOfLicenses = 10
if (($result = Read-Host "Enter the # of licenses or press enter to accept default value `"$numberOfLicenses`"") -eq '') {$numberOfLicenses} else {$numberOfLicenses = $result }
$isMultiSite = if ($env:isMultiSite) { $env:isMultiSite } else { Read-Host "Enter 0 for Single-Site or 1 for Multi-Site" }
$numberOfRequestOnlyUsers = 100
if (($result = Read-Host "Enter the # of Request Only users or press enter to accept default value `"$numberOfRequestOnlyUsers`"") -eq '') {$numberOfRequestOnlyUsers} else {$numberOfRequestOnlyUsers = $result }
$isAPIEnabled = 0
if (($result = Read-Host "Enter 1 for API Enabled or 0 for API Disabled or press enter to accept default value `"$isAPIEnabled`" for API Disabled") -eq '') {$isAPIEnabled} else {$isAPIEnabled = $result }
$isNamedUserLicense = Read-Host "Enter 1 for Named Users or 0 for Concurrent Users" 
}
else{
$numberOfLicenses = 150
$isMultiSite = 1
$numberOfRequestOnlyUsers = 100
$isAPIEnabled = 0
$isNamedUserLicense = 0
$message = "Since this is on Dev, hardcoding license!"
Write-Output $message
$message | Out-File $logfile -Append
}
#$renameLicenseFolderonC = "C:\Users\bmqradmin.BMQR\AppData\Local\Temp\.net\License Tool"
$renameLicenseFolderonC = "$home\AppData\Local\Temp\.net\License Tool"
if(Test-Path -Path $renameLicenseFolderonC) {
	Write-Output "Removing $renameLicenseFolderonC folder so the License Tool does not error" | Out-File $logfile -Append
    Remove-Item -Path $renameLicenseFolderonC -Recurse -Force 
}
Set-Location $PSScriptRoot
exec-sqlfile -databaseConnection $applicationdatabaseConnection -filepath ./fn_GetRequestOnlyLicenses.sql -continueOnError $continueOnError
$licenseKey = (& ./LicenseTool/"License Tool.exe" $lock $tenantID.Guid $numberOfLicenses $numberOfRequestOnlyUsers $isMultiSite $isNamedUserLicense $isAPIEnabled)
$licenseKey
exec-query -databaseConnection $applicationdatabaseConnection -sql "USE $($applicationDatabaseName);EXEC BMRAM.PutLicenseKey '$licenseKey';" -continueOnError $false

#####################################################################################################################################
#Must also include call to Putlicense
Set-Location $PSScriptRoot
#set RAM licenses (RAMCORE)
$licenseName = "RAMCORE"
if($isNamedUserLicense -eq "1")
 {
 $isNamedUserModel = $true
 }else{
 $isNamedUserModel = $false
 }
 $isConcurrentFallback = $false
 $allowBackgroundSync = $false
 $licenseCount = $numberOfLicenses
.\PutLicense.ps1    -databaseConnection $applicationdatabaseConnection `
                    -licenseName $licenseName `
                    -licenseCount $licenseCount `
                    -isNamedUserModel $isNamedUserModel `
                    -isConcurrentFallback $isConcurrentFallback `
                    -allowBackgroundSync $allowBackgroundSync
#set Request Only User licenses (RequestOnly)
$licenseName = "RequestOnly"
$isNamedUserModel = $true #always true
$isConcurrentFallback = $false
$allowBackgroundSync = $false
$licenseCount = $numberOfRequestOnlyUsers
.\PutLicense.ps1    -databaseConnection $applicationdatabaseConnection `
                    -licenseName $licenseName `
                    -licenseCount $licenseCount `
                    -isNamedUserModel $isNamedUserModel `
                    -isConcurrentFallback $isConcurrentFallback `
                    -allowBackgroundSync $allowBackgroundSync
#set RAMMobile licenses (RAMMobile)
$licenseName = "MOBILEAPP"
$isNamedUserModel = $true
$isConcurrentFallback = $true  #always true for rammobile
$allowBackgroundSync = $false
$licenseCount = "0"
.\PutLicense.ps1    -databaseConnection $applicationdatabaseConnection `
                    -licenseName $licenseName `
                    -licenseCount $licenseCount `
                    -isNamedUserModel $isNamedUserModel `
                    -isConcurrentFallback $isConcurrentFallback `
                    -allowBackgroundSync $allowBackgroundSync
$licenseinfo = (exec-query -databaseConnection $applicationdatabaseConnection -sql $sql -continueOnError $true) 
#if this errors go to C:\Users\bmqradmin.BMQR\AppData\Local\Temp\.net and rename the LicenseTool folder
Write-Output $licenseinfo 
$licenseinfo | Out-File $logfile -Append
 $message =
"
***************************************
Review the License info above that 
you just set!
Make sure it matches what the customer
purchased!
***************************************
"
Write-Output $message
$message | Out-File $logfile -Append
#######################################################################################################################
 #creates auth grant  #NOTE GRANT will SCRAMBLE ALL OSSIDS That are under the "Special" Auth source(s) so must
 #create user logins after grant so the ossids are not removed that I want to set       
 $message = " Create Authorization (2 year) Grant "
Write-Output $message
$message | Out-File $logfile -Append
#Verify...select * from system.AUTHORIZATIONGRANT
#remote BmqrAuthorizationGrantEmail if it already exists
$sql = "USE $($applicationDatabaseName); select * from BMRAM.cfgRegistry where keyname='bmqrauthorizationgrantemail'"
$keyexists =  exec-query -databaseConnection $applicationDatabaseConnection -sql $sql -continueOnError $continueOnError;
    if($keyexists)
        {
        $message = "BMRAM.cfgRegistry keyname='bmqrauthorizationgrantemail' EXISTS, deleting before adding Grant"
        Write-Output $message
        $message | Out-File $logfile -Append
        $sql = "USE $($applicationDatabaseName); Delete from BMRAM.cfgRegistry where keyname='bmqrauthorizationgrantemail'"
        exec-query -databaseConnection $applicationDatabaseConnection -sql $sql -continueOnError $continueOnError;
         }
#add the grant
.\AddAuthorizationGrant.ps1 -databaseConnection $applicationDatabaseConnection ` -authorizationGrantID $authorizationGrantID ` -authorizationGrantName $authorizationGrantName ` -expirationDate $expirationDate ` -comments $comments `
$sql = "USE $($applicationDatabaseName); select * from system.AUTHORIZATIONGRANT" 
$message = exec-query -databaseConnection $applicationDatabaseConnection -sql $sql -continueOnError $continueOnError;
Write-Output $message
$message | Out-File $logfile -Append
#set Authorization Grant Email Notification Key  (do this after the grant add above we don't email techsupport/bmqrcloudservices with request)
$message = "Setting Remote Assistance Email Notification registry values"
Write-Output $message
$message | Out-File $logfile -Append
$sql = "DECLARE @authorizationGrantEmail nvarchar(max)
SELECT @authorizationGrantEmail = 
(
    SELECT '$authGrantEmailRecipients' 'toRecipients',
    '$authGrantEmailBCCRecipients' 'bbcRecipients',
    '$authGrantEmailMessageSubject' 'messageSubject',
    '$authGrantEmailMessageBody' 'messageBody',
    '$authGrantEmailMailFormat' 'mailFormatID',
    '$authGrantEmailImportance' 'importanceID'
    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
)
EXEC BMRAM.setRegistryKeyValue 'BmqrAuthorizationGrantEmail', @authorizationGrantEmail"
exec-query -databaseConnection $applicationDatabaseConnection -sql $sql -continueOnError $continueOnError;
$sql = "USE $($applicationDatabaseName); select * from BMRAM.cfgRegistry where keyname='bmqrauthorizationgrantemail'"
$message =  exec-query -databaseConnection $applicationDatabaseConnection -sql $sql -continueOnError $continueOnError;
Write-Output $message
$message | Out-File $logfile -Append
#######################################################################################################################
#creates User login records  (moved this to after the license is set)
 $message = "Create BMQRAdmin, BMQRPM, BMQRAnalysts user login records in BMRAM "
Write-Output $message
$message | Out-File $logfile -Append
# Verify creation...select * from system.ADMIN_LOGONACCOUNT where PersonID in (
.\AddLogonAccount.ps1 -databaseConnection $applicationDatabaseConnection ` -BMQRAuthenticationSourceID $BMQRAuthenticationSourceID ` -BMQRPersonnelID $BMQRPersonnelID ` -osSID $BMQRAdminOSSID
.\AddLogonAccount.ps1 -databaseConnection $applicationDatabaseConnection ` -BMQRAuthenticationSourceID $BMQRAuthenticationSourceID ` -BMQRPersonnelID $BMQRPMPersonnelID ` -osSID $BMQRPMOSSID
.\AddLogonAccount.ps1 -databaseConnection $applicationDatabaseConnection ` -BMQRAuthenticationSourceID $BMQRAuthenticationSourceID ` -BMQRPersonnelID $BMQRAnalystPersonnelID ` -osSID $null
.\AddLogonAccount.ps1 -databaseConnection $applicationDatabaseConnection ` -BMQRAuthenticationSourceID $BMQRAuthenticationSourceID ` -BMQRPersonnelID $BMQRAnalyst2PersonnelID ` -osSID $null
.\AddLogonAccount.ps1 -databaseConnection $applicationDatabaseConnection ` -BMQRAuthenticationSourceID $BMQRAuthenticationSourceID ` -BMQRPersonnelID $BMQRAnalyst3PersonnelID ` -osSID $null
$sql = "USE $($applicationDatabaseName); select la.personid, la.ossid, la.authenticationsourceid, la.isactive from bmram.LogonAccounts la
inner join system.RTPERSONNEL p on la.PersonId = p.MemberID
where p.id like  'bmqr%'" 
$messagelogins = exec-query -databaseConnection $applicationDatabaseConnection -sql $sql -continueOnError $continueOnError;
if([string]::IsNullOrEmpty($messagelogins)) {
$message = "!!!!!!Error: Failure during BMQRAdmin, BMQRPM, BMQRAnalysts user login record creation in BMRAM"
Write-Output $message
$message | Out-File $logfile -Append
}else{
$message = "Created BMQRAdmin, BMQRPM, BMQRAnalysts user login records in BMRAM"
Write-Output $message
$message | Out-File $logfile -Append
$messagelogins | Out-File $logfile -Append
}
#######################################################################################################################
 $message =
"
Backup RAMDB Database to Prepare for adding the DB to AOAG
Backup RAMDB database and its log on the primary
"
Write-Output $message
$message | Out-File $logfile -Append
$bakname = $bmramDB + "_priorToRestore.bak"
$logname = $bmramDB + "_priorToRestore.trn"  #trying this, changed from .log
$target = "\\$primarySvr\G$\Backups\$customerID\$bmramDB"
if (!(Test-Path $target -PathType container))
    { New-Item -ItemType directory -Path $target }
#Backup-SqlDatabase -Database $bmramDB -BackupFile "\\$primarySvr\backups\$customerID\$bmramdb\$bakname" -ServerInstance $primarySvr    
#Backup-SqlDatabase -Database $bmramDB -BackupFile "\\$primarySvr\backups\$customerID\$bmramdb\$logname" -ServerInstance $primarySvr -BackupAction "Log"     
$backupCMD, $ramDBFiles, $DocDBFiles = GenerateBackupDatabaseCommand $customerID "FULL" $false
$ramDBFullBackup = $ramDBFiles
Invoke-Expression($backupCMD)
$backupCMD, $ramDBFiles, $DocDBFiles = GenerateBackupDatabaseCommand $customerID "LOG" $false
$ramDBTranBackup = $ramDBFiles
Invoke-Expression($backupCMD)
Sleep 5
#######################################################################################################################
  $message = "Restore the RAMDB database on the secondary (using Replace)"
Write-Output $message
$message | Out-File $logfile -Append
Restore-SqlDatabase -Database $bmramDB -BackupFile @($ramDBFullBackup) -ServerInstance $secondarySvr  -ReplaceDatabase
Sleep 5
#######################################################################################################################
#add the RAMDatabaseOwner as owner to the RAMDB on the secondary
  $message = " Change database owner to RAMDatabaseOwner on RAMDB on the secondary"
Write-Output $message
$message | Out-File $logfile -Append
$owner = $databaseOwnerAccount;
$sql = "ALTER AUTHORIZATION ON DATABASE::$($bmramdb) TO [$($databaseOwnerAccount)]";
Invoke-Sqlcmd -ServerInstance $secondarySvr -Database master -Query $sql -Verbose 4>&1 | Out-File $logfile -Append
#######################################################################################################################
  $message = "Restore the RAMDB database and log on the secondary (using NO RECOVERY) "
Write-Output $message
$message | Out-File $logfile -Append
Restore-SqlDatabase -Database $bmramDB -BackupFile @($ramDBFullBackup) -ServerInstance $secondarySvr -ReplaceDatabase -NoRecovery 
Restore-SqlDatabase -Database $bmramDB -BackupFile @($ramDBTranBackup) -ServerInstance $secondarySvr -RestoreAction "Log" -ReplaceDatabase -NoRecovery 
Sleep 5
##########################################################################################################################################
  $message = "Adding the $customer RAMDB to the AG "
Write-Output $message
$message | Out-File $logfile -Append
$pathAGprim = "SQLSERVER:\SQL\" + $primarySvr + "\Default\AvailabilityGroups\" + $ag
$pathAGsec = "SQLSERVER:\SQL\" + $secondarySvr + "\Default\AvailabilityGroups\" + $ag
Add-SqlAvailabilityDatabase -Path $pathAGprim -Database $bmramDB
Add-SqlAvailabilityDatabase -Path $pathAGsec -Database $bmramDB
Sleep 5
#######################################################################################################################
  $message = "Set BACKUP_DB property ON "
Write-Output $message
$message | Out-File $logfile -Append
Invoke-Sqlcmd -ServerInstance $listener -Database "BMRAMControl" -Query "EXEC dbo.dba_SetCustomerProperty @CustomerID='$customerID', @Name='BACKUP_DB', @Value='ON'"
######################################################################################################################
#9/25/2020 Vishal changeset 43827
$sql = @"
USE $($applicationDatabaseName);
DECLARE @alterStatement NVARCHAR(MAX)
DECLARE @tables TABLE 
(
	tableName		NVARCHAR(255)
	,fillFactorNum	NVARCHAR(3)
);

INSERT INTO @tables
SELECT	QUOTENAME(s.name) + N'.' + QUOTENAME(t.name)
		,CASE
			WHEN RT.TableType IN ('TTMETADATA') THEN 100
			WHEN RT.TableType IN ('TTLOG', 'TTLOGBASE') THEN 95
			WHEN RT.IsConfigTable = 1 THEN 90
			WHEN RT.TableType IN ('TTBASE','TTCOMMON','TTCOMMONLONGTEXT','TTDETAIL','TTDETAILLONGTEXT','TTHEADER') THEN 85
			ELSE 90
		END
FROM sys.tables T
INNER JOIN sys.schemas s ON s.schema_id = t.schema_id 
LEFT JOIN BMRAM.tblTables RT ON RT.SchemaName = S.name and T.name = RT.TableName
WHERE	EXISTS		(SELECT * 
					FROM sys.indexes i	
					WHERE i.object_id = t.object_id
					) AND 
		S.name <> 'dbo'
DECLARE @tableName	NVARCHAR(255)
DECLARE @fillfactor	NVARCHAR(3);
WHILE EXISTS(SELECT * FROM @tables)
BEGIN
	SELECT TOP 1 @tableName = T.tableName
				,@fillfactor = T.fillFactorNum
	FROM @tables T;
  SET @alterStatement = N'ALTER INDEX ALL ON ' + @tableName + ' REBUILD WITH (FILLFACTOR = ' + @fillfactor + ');';
	EXEC SP_EXECUTESQL @alterStatement;
	DELETE FROM @tables
	WHERE tableName = @tableName;
END
"@
Write-Output $sql;
exec-query -databaseConnection $applicationDatabaseConnection -sql $sql -continueOnError $continueOnError;
$sql = @"
USE $($applicationDatabaseName);
EXEC sp_updatestats
"@
Write-Output $sql;
exec-query -databaseConnection $applicationDatabaseConnection -sql $sql -continueOnError $continueOnError;

################################################################################################################
#begin Incident 36128 placement, valid for 6.3.6
  $message = " Beginning Incident 36128 Placement "
$message | Out-File $logfile -Append
$patchlocation = "H:\DeploymentSource\6.3.6Upgrade\DB\UpgradeFiles\6.3.6\Schema\"
Set-Location $patchlocation;
$patchfileName = "schema_1_28143_prevent_core_auditing_configuration.sql"
$message = "
Running Incident 36128  Placement on $bmramdb "
Write-Output $message
$message | Out-File $logfile -Append
$messageReturned = Invoke-SqlCmd -ServerInstance $primarySvr -Database $bmramDB -InputFile $patchfileName -Verbose 4>&1
$messageReturned = $messageReturned.Message
$message ="
$messageReturned
"
Write-Output $message
$message | Out-File $logfile -Append 
$message = "
Completed Incident 36128  placement on $bmramdb
"
Write-Output $message
$message | Out-File $logfile -Append
Set-Location $PSScriptRoot;
#########################################################################################################
#####INSTALL WEBAPI so that permissions are applied to the loginlessuser (even though the clean db has the webapi installed, I drop the loginlessuser and recreate it so I have to reintall to get permissions right
   $path = "H:\DeploymentSource\WebApi"
   #$versionFolder = Get-ChildItem $path | Sort-Object -Property Name -Descending | Select-Object -Property Name -ExpandProperty Name -First 1
   $versionfolder = "WEBAPI-6.3.6"
   Write-Host "Installing WEBAPI version $versionfolder, if not correct stop"
   pause
   #if($isProduction -eq "0"){
   #if(($result = Read-Host "Enter the WebAPI Version or press enter to accept default value `"$versionFolder`"") -eq '') {$versionFolder} else {$versionFolder = $result}
   #}
   $path = "$path\$versionFolder"
   $message = 
   "Installing WebApi Version: $versionFolder ..."
   Write-Output $message
   $message | Out-File $logfile -Append
     #$path = "H:\DeploymentSource\WebApi\$WebAPIVersion\"
     Set-Location $path
     cd Scripts
     .\InstallGraphQL.ps1 -Server $primarySvr -DBName $bmramdb
     #copy install logfile to H:\CustomerDeployments\$moniker
     $installdestPath = "H:\CustomerDeployments\$customerID"
     Set-Location $installdestPath
     $getlog = Get-ChildItem $installdestPath | where{$_.Name -match 'installGraphQL'} | sort LastWriteTime | Select -Last 1
     $getlog = $getlog.FullName
     $webapiInstallLogfileInfo = Import-Csv $getlog
     $webapiInstallLogfileInfo | Out-File $logfile -Append
     $newName = "InstallGraphQL_duringProvision" + $versionFolder + "_" + $logDate + "_" + $customerID + ".txt"
     Rename-Item $getlog -NewName $newName -Force
     Set-Location $PSScriptRoot
     
     #check version after install
     $WebAPIVersionAfterInfo = Invoke-Sqlcmd -ServerInstance $primarySvr -Database $bmramdb -Query "select * from bmram.tblInstalledModules where ModID = 'RAMWEBAPI'" -Verbose 4>&1
     Write-Output $WebAPIVersionAfterInfo 
     $ModID = $WebAPIVersionAfterInfo.ModID
     $ModName = $WebAPIVersionAfterInfo.ModName 
     $ModVersion = $WebAPIVersionAfterInfo.ModVersion
     $message ="
     WebAPI Info:
      WebAPI ModID: $ModID
      WebAPI ModName: $ModName 
      WebAPI ModVersion: $ModVersion  
     " | Out-File $logfile -Append
#########################################################################################################
#####INSTALL MOBILE APP 
#need to grab the logfile that this creates and add it to the provisioning logfile
$message = 
   "Installing Mobile App..."
   Write-Output $message
   $message | Out-File $logfile -Append
#$versionfolder = "WEBAPI-6.3.4.1"
$mobileLocation = "H:\DeploymentSource\WebAPI\$versionfolder\Scripts"
Set-Location $mobileLocation
$API_URL="$apimgtsvcURL/$customerID/mobile"
$AUDIENCE="RAMWebAPI"
 .\InstallMobileApp.ps1 -dbConnection $applicationDatabaseConnection -API_URL $API_URL -AUDIENCE $AUDIENCE
#need to grab the logs from the install and append to customer's logfile
     $installdestPath = "H:\CustomerDeployments\$customerID"
     Set-Location $installdestPath
     $getlog = Get-ChildItem $installdestPath | Where-Object{$_.Name -match 'installMobileApp'} | Sort-Object LastWriteTime | Select-Object -Last 1
     $getlog = $getlog.FullName
     $mobilelogfile = $getlog
     $mobilelogfileInfo = Import-Csv $mobilelogfile
     $mobilelogfileInfo | Out-File $logfile -Append
     $newName = "InstallMobileApp_duringProvision" + $versionFolder + "_" + $logDate + "_" + $customerID + ".txt"
     Rename-Item $getlog -NewName $newName -Force
##########################################################################################################     
#create the mobile API record in API Mgt Svc
Select-AzSubscription -Subscription $SubscriptionName -Tenant $azureTenantid
Set-AzContext -Subscription $SubscriptionName
#create the mobile API record in the API Mgt Svc
$mobileDisplayname = $customerID + "-mobile"
$mobileWEBAPIName = $customerID + "_mobile"
$integrationServiceURL = "https://" + $webAPIwebapp + ".azurewebsites.net/api/graphql/SYSTEM"  #mobile uses the same as integration
$signingKeySecretName = "MobileWEBAPIAuth0SigningSecret"
$sigingKeySecure = (Get-AzKeyVaultSecret -VaultName $vaultName -Name $signingKeySecretName).SecretValue
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sigingKeySecure)
$signingKey = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

######################################################################################

#create CName record and mobile api with terraform 

$message = " Creating Customer instance CName record with terraform by passing the variables to tfvars file instead of bicep template"

Write-Output $message
$message | Out-File $logfile -Append

#Defining variables for terraform.tfvars file
$tfvarsFile = "terraform\variables.tfvars"
$terraformScriptPath = ".\terraform"

$tfvarsContent = @"
subdomain = "$subdomain"
resource_group = "$resourceGroup"
dns_zone = "$DNSZone"
ttl = "3600"
alias_gateway = "$aliasGateway" 
subscription_name = "$SubscriptionName"
azure_tenant_id = "$azureTenantid"
customer_id = "$customerID"
api_mgmt_service_name = "$apimgtsvcName"
service_url = "$integrationServiceURL"
tenant_id = "$tenantID.guid"
signing_key = "$signingKey"
audience = "$AUDIENCE"
issuer = "$issuer"
mobile_display_name = "$mobileDisplayname"
mobile_webapi_name = "$mobileWEBAPIName"
"@

Set-Content -Path $tfvarsFilePath -Value $tfvarsContent
Write-Output "Terraform variable file created at $tfvarsFilePath"

##################################################################################################
#switching to Azure CLI commands
az login --identity
az account set -s $subscriptionName
az configure --defaults group=$appEnvResourceGroup location=$region 
########################################################################
$signalrApp = $signalrwebapp
$dnsCname = $customerID + "." + $DNSZone 
$serverUrl = "https://" + $dnsCname
$message = "
*****************************************************************
    Update SignalR web app's CORS Allowed Origins with
               customer application URL
    Customer URL: $serverUrl
*****************************************************************"
Write-Output $message
$message | Out-File $logfile -Append
az webapp cors add -n $signalrApp --allowed-origins $serverUrl --resource-group $appEnvResourceGroup --only-show-errors
$allowedOrigins = $serverURL
    $OriginNotExists = az webapp cors show --name $signalrApp --resource-group $appEnvResourceGroup --query "contains(to_string(length(allowedOrigins[?contains(@, '$allowedOrigins')])),'0')"
     if ($OriginNotExists -eq "false"){
        $CORSDetails = "CORS Allowed Origins now includes " + $allowedOrigins
        }Else{
        $CORSDetails = "WARNING: CORS Allowed Origins NOT UPDATED!!!"
        }
$message = "
*****************************************************************
    Updated SignalR web app's CORS Allowed Origins with
               customer application URL
    Customer URL: $serverUrl
    SignalR Web App: $signalrApp
    CORS Details:
    $CORSDetails
*****************************************************************"
Write-Output $message
$message | Out-File $logfile -Append
#########################################################################################
$ramreportsApp = $ramreportswebapp
$message = "
*****************************************************************
    Update RAMREPORTS web app's CORS Allowed Origins with
               customer application URL
    Customer URL: $serverUrl
*****************************************************************"
Write-Output $message
$message | Out-File $logfile -Append
az webapp cors add -n $ramreportsApp --allowed-origins $serverUrl --resource-group $appEnvResourceGroup --only-show-errors
$allowedOrigins = $serverURL
    $OriginNotExists = az webapp cors show --name $ramreportsApp --resource-group $appEnvResourceGroup --query "contains(to_string(length(allowedOrigins[?contains(@, '$allowedOrigins')])),'0')"
     if ($OriginNotExists -eq "false"){
        $CORSDetails = "CORS Allowed Origins now includes " + $allowedOrigins
        }Else{
        $CORSDetails = "WARNING: CORS Allowed Origins NOT UPDATED!!!"
        }
$message = "
*****************************************************************
    Updated RAMREPORTS web app's CORS Allowed Origins with
               customer application URL
    Customer URL: $serverUrl
    RAMREPORTS Web App: $ramreportsApp
    CORS Details:
    $CORSDetails
*****************************************************************"
Write-Output $message
$message | Out-File $logfile -Append
######################################################################################
$date = Get-date
$testEmailToAccount = "bmqrcloudservices@coolblue.com"  #send to cloud team
#$emailProfile  = $environmenttype
$testEmailSubject = "New R4 Customer Instance Deployed: $customerName";
$testEmailBody = "
 <h2><strong>New R4 customer deployment information:</strong></h2>
 <p><strong>Deployed to:</strong> $clusterPrefix <br>
 <strong>Date Deployed:</strong>  $date <br>
 <strong>CustomerID:</strong>  $customerID <br>
 <strong>Customer Name:</strong>  $customerName <br>
 <strong>SN:</strong>  $customerSN <br>
 <strong>Website:</strong>  $serverURL <br>
 <strong>BMQRAdmin username:</strong>  $BMQRAdminuser <br>
 <strong>BMQR Project Manager username:</strong>  $BMQRPMUser <br>
 <strong>Auth Grant ID:</strong>  $authorizationGrantID <br>
 <strong>Auth Grant Name:</strong>  $authorizationGrantName <br>
 <strong>Auth Grant Expiry:</strong>  $expirationDate <p>
 "
#.\TestDatabaseMail.ps1  -databaseConnection $tenantDatabaseConnection `	-emailProfile $emailProfile ` -databaseName $targetdatabases ` -databaseserver $primarySvr ` -testEmailToAccount $testEmailToAccount ` 	-testEmailSubject $testEmailSubject ` -testEmailBody $testEmailBody 
                $_testEmailSubject = [string]::Format($testEmailSubject,$bmramdb);
				$_testEmailBody = [string]::Format($testEmailBody,$bmramdb);
				$sql = @"
USE $($bmramdb);  
DECLARE
	@mailFormatID		UNIQUEIDENTIFIER
	,@importanceID		UNIQUEIDENTIFIER
DECLARE @mailItemID	INT;
DECLARE @mailFormat			NVARCHAR(128) = 'HTML',
		@importance			NVARCHAR(6) = 'Normal';	
SELECT @mailFormatID  = MemberID FROM system.MAILFORMAT WHERE Name  = @mailFormat;
SELECT @importanceID = MemberID FROM system.MAILIMPORTANCE WHERE Name = @importance;
--send a test email Tenant's RAM database
EXECUTE BMRAM.sendToEmail '$($emailProfile)','$($testEmailToAccount)', NULL, '$($_testEmailSubject)', '$($_testEmailBody)', @mailFormatID, @importanceID, 0;
"@;
				#Write-Verbose $sql;
				exec-query -databaseConnection $applicationdatabaseConnection -sql $sql -continueOnError $continueOnError;
###################################################################################################################
#pull RAMCORE info
#check version 
  $message =
"
Pulling version info from BMRAM.InstalledModules
"
$message | Out-File $logfile -Append
$message = "Provisioned with version:
   "
Write-Output $message
$message | Out-File $logfile -Append
$sql = "select modID, ModVersion from bmram.tblInstalledModules"
$Afterupgradeversions = exec-query -databaseConnection $applicationDatabaseConnection -sql $sql -continueOnError $continueOnError;
foreach ($Afterupgradeversion in $Afterupgradeversions){
   $AfterupgradeversionsModID = $Afterupgradeversion.modID
   $AfterupgradeversionsModVersion = $Afterupgradeversion.ModVersion
   $message = $AfterupgradeversionsModID + ": " + $AfterupgradeversionsModVersion   
   Write-Output $message 
   $message | Out-File $logfile -Append
   }
#################################################################################################
#PROMPT to update RT.Personnel table email addresses with apptesting@coolblue.com, only if DEVELOPEMENT subscription
if($subscriptionName -eq "BMQR-BPT-DEVELOPMENT"){
$updateEmailAddrYN = "N"
if(($result = Read-Host "Do you want to replace Non-BMQR Admin email addresses with apptesting@coolblue.com? (Y or N)? or press enter to accept default value `"$updateEmailAddrYN`"") -eq '') {$updateEmailAddrYN} else {$updateEmailAddrYN= $result }
  if($updateEmailAddrYN -eq "Y")
  {
  $sql = "UPDATE SYSTEM.RTPERSONNEL SET Email = 'apptesting@coolblue.com' WHERE ID not like ('BMQR%')"
  $RowsUpdated = exec-query -databaseConnection $applicationDatabaseConnection -sql $sql -continueOnError $continueOnError -Verbose;
  $message = "
  Updated System.RTPersonnel email addresses to apptesting@coolblue.com except for BMQR admin users
  Rows Updated: $RowsUpdated
  "
  Write-Output $message
  $message | Out-File $logfile -Append
  }
}
#####################################################################################################################################################################################
#Close all SQL connections to the RAMDB, Tenant, and BMRAMControl that you previously opened
  $message =
"
Closing SQL Connections
"
Write-Output $message
$message | Out-File $logfile -Append
if($closeAppDBConnection){
  $applicationDatabaseConnection.Close();}
if($closeTenantDbConnection){
  $tenantDatabaseConnection.Close();}
if($closeBMRAMControlConnection){
  $BMRAMControlConnection.Close();}
#########################################################################################################################################################
Write-Host "Script has been completed"
$message = "Taking full backup with EXEC_BACKUPS runbook"
Write-Output $message
$message | Out-File $logfile -Append
Select-AzSubscription -Subscription $SubscriptionName -Tenant $azureTenantid
Set-AzContext -Subscription $SubscriptionName
ExecuteRunbookEXEC_BACKUPS -clusterNamePrefix $clusterPrefixInfo -customerName $customerID
$message = "
*******************************************************************************************
 Logfile resides here: $logfile 
******************************************************************************************"
Write-Output $message
$logfileEndDate = Get-Date
$totalrestoretime = NEW-TIMESPAN –Start $logfileDate –End $logfileEndDate
$totalrestoretimeHRS = $totalrestoretime.TotalHours
$totalrestoretimeHRSRounded = [math]::Round($totalrestoretimeHRS,2)
$message = "
*****************************************************************
       $customerID Deployment Finished!!!!
              $logfileEndDate   
 Total Time in Hours for Deployment: $totalrestoretimeHRSRounded   
*****************************************************************"
Write-Output $message
$message | Out-File $logfile -Append
Invoke-Item $logfile
