
function Get-WebConfigApiToken
{
Param (

    [Parameter(Mandatory=$True)]
    [string]
    $tenant,

    [Parameter(Mandatory=$True)]
    [string]
    $vaultName
)

    # Retrieve a new Token from Auth0 using Client Credentials retrieved from the Vault
    $url = "https://$tenant/oauth/token"
    $audience = "https://$tenant/api/v2/"
    
    # Adjust these to account for multiple tenants
    if($tenant -eq "bluemountainsoftware.auth0.com"){
    $clientID= (Get-AzKeyVaultSecret -VaultName $vaultName -Name "Auth0TokenRefreshClientID-BMS").SecretValue
    $clientID= [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($clientID))   
    $clientsecret= (Get-AzKeyVaultSecret -VaultName $vaultName -Name "Auth0TokenRefreshClientSecret-BMS").SecretValue
    $clientsecret= [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($clientsecret))

     }elseif($tenant -eq "coolbluecloud.auth0.com"){  
    $clientID= (Get-AzKeyVaultSecret -VaultName $vaultName -Name "Auth0TokenRefreshClientID").SecretValue 
    $clientID= [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($clientID))   
    $clientsecret= (Get-AzKeyVaultSecret -VaultName $vaultName -Name "Auth0TokenRefreshClientSecret").SecretValue
    $clientsecret= [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($clientsecret))}

    $body = @{
        client_id = $clientID
        client_secret = $clientsecret
        audience = $audience
        grant_type = 'client_credentials'
    }

    $response = Invoke-RestMethod -Method Post -Uri $url -Body $body 

    # Get the Auth0WebConfig token from the Auth0 response
    $Global:auth0WebConfigApiToken = $response.access_token

"
Global Variables Set:

Variable: auth0WebConfigApiToken
Value:   $auth0WebConfigApiToken
"

}


function Get-InstallationApiToken
{
Param (

    [Parameter(Mandatory=$True)]
    [string]
    $tenant,

    [Parameter(Mandatory=$True)]
    [string]
    $vaultName
)


    # Retrieve a new Token from Auth0 using Client Credentials retrieved from the Vault
    $url = "https://$tenant/oauth/token"
    $audience = "https://$tenant/api/v2/"


    if($tenant -eq "bluemountainsoftware.auth0.com"){
    $clientID= (Get-AzKeyVaultSecret -VaultName $vaultName -Name "Auth0DeploymentClientID-BMS").SecretValue
    $clientID= [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($clientID))  
    $clientsecret= (Get-AzKeyVaultSecret -VaultName $vaultName -Name "Auth0DeploymentClientSecret-BMS").SecretValue
    $clientsecret= [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($clientsecret))  
     }elseif($tenant -eq "coolbluecloud.auth0.com"){ 
    $clientID= (Get-AzKeyVaultSecret -VaultName $vaultName -Name "Auth0DeploymentClientID").SecretValue
    $clientID= [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($clientID))    
    $clientsecret= (Get-AzKeyVaultSecret -VaultName $vaultName -Name "Auth0DeploymentClientSecret").SecretValue
    $clientsecret= [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($clientsecret))}

    $body = @{
        client_id = $clientID
        client_secret = $clientsecret
        audience = $audience
        grant_type = 'client_credentials'
    }

    $response = Invoke-RestMethod -Method Post -Uri $url -Body $body 

    # Get the Auth0WebConfig token from the Auth0 response
    $Global:auth0InstallationApiToken = $response.access_token


"
Global Variables Set:

Variable: auth0InstallationApiToken
Value:   $auth0InstallationApiToken
"


}

Export-ModuleMember -Function 'Get-WebConfigApiToken'
Export-ModuleMember -Function 'Get-InstallationApiToken'


Export-ModuleMember -Variable auth0WebConfigApiToken
Export-ModuleMember -Variable auth0InstallationApiToken
