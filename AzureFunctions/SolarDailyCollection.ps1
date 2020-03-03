# Input bindings are passed in via param block.
param($Timer)

# Get the current universal time in the default string format
$currentUTCtime = (Get-Date).ToUniversalTime()

# The 'IsPastDue' porperty is 'true' when the current function invocation is later than scheduled.
if ($Timer.IsPastDue) {
    Write-Host "PowerShell timer is running late!"
}

# Write an information log with the current time.
Write-Host "PowerShell timer trigger function ran! TIME: $currentUTCtime"


$logType = "SolarDaily"

$ID = $env:WorkspaceID
$key = $env:SharedKey

$uri = "https://monitoringapi.solaredge.com/site/" + $env:site + "/overview?api_key=" + $env:apikey

$coll = invoke-restmethod -uri $uri

$solar = New-Object -TypeName psobject 
$solar | add-member -name Date -value $coll.overview.lastUpdateTime -membertype NoteProperty
$solar | add-member -name Wh -value $coll.overview.lastdaydata.energy -membertype NoteProperty

$solar = convertto-Json $solar

$TimeStampField = get-date
$TimeStampField = $TimeStampField.GetDateTimeFormats(115)


Function Post-LogAnalyticsData($customerId, $sharedKey, $body, $logType)
{
    $method = "POST"
    $contentType = "application/json"
    $resource = "/api/logs"
    $rfc1123date = [DateTime]::UtcNow.ToString("r")
    $contentLength = $body.Length

    $xHeaders = "x-ms-date:" + $rfc1123date 
    $stringToHash = $method + "`n" + $contentLength + "`n" + $contentType + "`n" + $xHeaders + "`n" + $resource

    $bytesToHash = [Text.Encoding]::UTF8.GetBytes($stringToHash)
    $keyBytes = [Convert]::FromBase64String($sharedKey)

    $sha256 = New-Object System.Security.Cryptography.HMACSHA256
    $sha256.Key = $keyBytes
    $calculatedHash = $sha256.ComputeHash($bytesToHash)
    $encodedHash = [Convert]::ToBase64String($calculatedHash)
    $authorization = 'SharedKey {0}:{1}' -f $customerId,$encodedHash

    $signature = $authorization
    $uri = "https://" + $customerId + ".ods.opinsights.azure.com" + $resource + "?api-version=2016-04-01"

    $headers = @{
        "Authorization" = $signature;
        "Log-Type" = $logType;
        "x-ms-date" = $rfc1123date;
        "time-generated-field" = $TimeStampField;
    }

    $response = Invoke-WebRequest -Uri $uri -Method $method -ContentType $contentType -Headers $headers -Body $body -UseBasicParsing
    return $response.StatusCode

}


Post-LogAnalyticsData -customerId $ID -sharedKey $Key -body ([System.Text.Encoding]::UTF8.GetBytes($solar)) -logType $logType









