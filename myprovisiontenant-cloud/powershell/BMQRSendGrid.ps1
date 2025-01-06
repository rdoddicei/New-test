function Send-MailWithSendgrid
{
 Param
    (
        [Parameter(Mandatory=$true)]
        [string] $from,
 
        [Parameter(Mandatory=$true)]
        [String[]] $to,
 
        [Parameter(Mandatory=$true)]
        [string] $apiKey,
 
        [Parameter(Mandatory=$true)]
        [string] $subject,
 
        [Parameter(Mandatory=$true)]
        [string] $body,

        [Parameter(Mandatory=$false)]
        [switch] $highPriority = $false,

        [Parameter(Mandatory=$false)]
        [string[]] $attachments = @()
 
    )

    [string]$formattedEmails = ""
  
    $formattedEmails += "{ 
			`"email`": `"$($To[0])`"
		}"
    for($i = 1; $i -lt $To.Length; $i++)
    {
      $formattedEmails += ", { 
			`"email`": `"$($To[$i])`"
		}"
    }

    $headers = @{}
    $headers.Add("Authorization","Bearer $apiKey")
    $headers.Add("Content-Type", "application/json")
    $personalisation = "{`"personalizations`": [{
		`"to`": [$($formattedEmails)
        ],
		`"subject`": `"$($subject)`"
	}],"

    if($highPriority)
    {
     $personalisation +=   "`"headers`": {
    `"X-Priority`": `"1`",
    `"Priority`": `"urgent`",
    `"Importance`": `"high`"
    },"
    }

    if($attachments.Length -gt 0)
    {
      $personalisation += "`"attachments`": ["

      for($i = 0; $i -lt $attachments.Length; $i++)
      {
          $file = $attachments[$i]
          $fileContent = Get-Content $file -Encoding UTF8 -Raw
          $fileContentBytes = [System.Text.Encoding]::UTF8.GetBytes($fileContent)
          $fileContentEncoded = [System.Convert]::ToBase64String($fileContentBytes)
          $fileContentEncoded | Set-Content ($fileName + ".b64")

          $personalisation += "{ `"content`": `"$($fileContentEncoded)`",
                                 `"filename`": `"$($file | Split-Path -Leaf)`"
                                 }"
          if(($attachments.Length - $i) -gt 1)
          {
            $personalisation += ","
          }
      }
        $personalisation += "],"                    
    }

    $json = [ordered]@{
                                from = @{email = "$from"}
                                content = @( @{ type = "text/html"
                                            value = "$body" }
                                )} | ConvertTo-Json -Depth 10
    $jsonRequest = $personalisation + $json.Substring(1)
    Invoke-RestMethod   -Uri "https://api.sendgrid.com/v3/mail/send" -Method Post -Headers $headers -Body $jsonRequest 
}
