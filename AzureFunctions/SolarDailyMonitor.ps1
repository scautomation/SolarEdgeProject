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

# Replace with your Workspace ID
$CustomerId = $env:ID 

# Replace with your Primary Key
$SharedKey = $env:key

# Specify the name of the record type that you'll be creating
$LogType = "SolarMonitor"

$TimeStampField = get-date
$TimeStampField = $TimeStampField.GetDateTimeFormats(115)


$powerURI = "https://monitoringapi.solaredge.com/site/" + $env:site + "/overview?api_key=" + $env:apikey
$statusURI = "https://monitoringapi.solaredge.com/site/" + $env:site + "/details?api_key=" + $env:apikey
$invURI = "https://monitoringapi.solaredge.com/site/" + $env:site + "/inventory?api_key=" + $env:apikey

$power = invoke-restmethod -uri $powerURI
$status = invoke-restmethod -uri $statusURI
$inv = invoke-restmethod -uri $invURI




#Build JSON Output, grabbing Inventory data, connected Optimizers and Status
$solar = $status.details | select-object Status, peakpower, lastupdatetime
$westarray = $inv.inventory.inverters | where-object {$_.name -eq "Inverter 2"}
$eastarray = $inv.inventory.inverters | where-object {$_.name -eq "Inverter 1"}



#Build final JSON adding Current Power, Total Power for the day and inventory data to Solar variable
$solar | add-member -name WestInverter -value $westarray.name -MemberType NoteProperty
$solar | add-member -name WestCPUVersion -value $westarray.cpuVersion -MemberType NoteProperty
$solar | add-member -name WestPanelCount -value $westarray.connectedOptimizers -MemberType NoteProperty
$solar | add-member -name EastInverter -value $eastarray.name -MemberType NoteProperty
$solar | add-member -name EastCPUVersion -value $eastarray.cpuVersion -MemberType NoteProperty
$solar | add-member -name EastPanelCount -value $eastarray.connectedOptimizers -MemberType NoteProperty
$solar | add-member -name CurrentOutput -value $power.overview.currentPower.power -MemberType NoteProperty
$solar | Add-Member -name TodaysOutput -value $power.overview.lastDayData.energy -MemberType NoteProperty

#Conver to JSON for Log Analytics Payload
$solar = convertto-json $solar



Function Build-Signature ($customerId, $sharedKey, $date, $contentLength, $method, $contentType, $resource)
{
    $xHeaders = "x-ms-date:" + $date
    $stringToHash = $method + "`n" + $contentLength + "`n" + $contentType + "`n" + $xHeaders + "`n" + $resource

    $bytesToHash = [Text.Encoding]::UTF8.GetBytes($stringToHash)
    $keyBytes = [Convert]::FromBase64String($sharedKey)

    $sha256 = New-Object System.Security.Cryptography.HMACSHA256
    $sha256.Key = $keyBytes
    $calculatedHash = $sha256.ComputeHash($bytesToHash)
    $encodedHash = [Convert]::ToBase64String($calculatedHash)
    $authorization = 'SharedKey {0}:{1}' -f $customerId,$encodedHash
    return $authorization
}


# Create the function to create and post the request
Function Post-LogAnalyticsData($customerId, $sharedKey, $body, $logType)
{
    $method = "POST"
    $contentType = "application/json"
    $resource = "/api/logs"
    $rfc1123date = [DateTime]::UtcNow.ToString("r")
    $contentLength = $body.Length
    $signature = Build-Signature `
        -customerId $customerId `
        -sharedKey $sharedKey `
        -date $rfc1123date `
        -contentLength $contentLength `
        -fileName $fileName `
        -method $method `
        -contentType $contentType `
        -resource $resource
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

# Submit the data to the API endpoint
Post-LogAnalyticsData -customerId $customerId -sharedKey $sharedKey -body ([System.Text.Encoding]::UTF8.GetBytes($solar)) -logType $logType

