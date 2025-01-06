
function Add-BmqrAuthentication($subscriptionName)
{

    # The tenant value is fixed
    $Global:azureTenantid = "d6ed1c6e-9709-4bbb-a7bf-e9ec567574bc" # Blue Mountain Quality Resources tenant

    if($subscriptionName -eq "BMQR-BPT-DEVELOPMENT")
    {
        $Global:appID="6d890d5a-daf8-44f1-b47b-b374aedd3d69" # BMQRAuthenticateDev
        $Global:certName = "BMQRAuthenticateDEV"
        $Global:vaultName = "BMQRKeyVaultDev"                   
        $Global:fileShare="webcontent"
        $Global:backupDestAccount="sharedwebcontent"
        $Global:backupDestDir="\\$backupDestAccount.file.core.windows.net\$fileShare\Backups"
        $Global:keyname=$backupDestAccount
    }

    if($subscriptionName -eq "BMQR-BPT-PRODUCTION")
    {
        $Global:appID="3b2cab28-4d01-43bd-a79d-0b65f8472cb6" # BMQRAuthenticateProd
        $Global:certName = "BMQRAuthenticateProd"
        $Global:vaultName = "BMQRKeyVault"
        $Global:fileShare="bmqrdata"
        $Global:backupDestAccount="bmqrdatastorage"
        $Global:backupDestDir="\\$backupDestAccount.file.core.windows.net\$fileShare\Backups"
        $Global:keyname=$backupDestAccount
    }

    # Retrieve the authentication certificate from Local Machine
    
    $cert = Get-ChildItem "Cert:\LocalMachine\My"  | Where-Object {$_.Subject -like "CN=$certName"}

    if([string]::IsNullOrEmpty($cert)){
       #login with azure cli using the bmqrauthenticateXXX_Managed user assigned identity for the VM
       az login --identity
       az account set -s $subscriptionName

       #login with powershell  using the bmqrauthenticateXXX_Managed user assigned identity for the VM
       Connect-AzAccount -Identity
       Select-AzSubscription -Subscription $subscriptionName -Tenant $azureTenantid

      }else{
           
       # Login using certificate
       Connect-AzAccount -ServicePrincipal -CertificateThumbprint $cert.Thumbprint -Tenant $azureTenantid -ApplicationId $appID -Subscription $subscriptionName
       Select-AzSubscription -Subscription $subscriptionName -Tenant $azureTenantid

      }
    
"
Global Variables Set:

Variable: azureTenantid
Value:   $azureTenantid

Variable: appID
Value:   $appID

Variable: certName
Value:   $certName

Variable: vaultName
Value:   $vaultName

Variable: fileShare
Value:   $fileShare

Variable: backupDestAccount
Value:   $backupDestAccount

Variable: backupDestDir
Value:   $backupDestDir

Variable: keyname
Value:   $keyname
"


}

Export-ModuleMember -Function 'Add-BmqrAuthentication'
