#Requires -Version 5.1
param([string]$BaseUrl = 'http://localhost:5024')

$ErrorActionPreference = 'Stop'
$BaseUrl = $BaseUrl.TrimEnd('/')
$failures = [System.Collections.Generic.List[string]]::new()
$createdIds = [System.Collections.Generic.HashSet[int]]::new()
$script:testCount = 0
$script:requestCount = 0
$userA = 'Bearer user-a-token'
$userB = 'Bearer user-b-token'
$admin = 'Bearer admin-token'
$runTag = [Guid]::NewGuid().ToString('N').Substring(0, 12)
$valid = [ordered]@{
    title = "Validation $runTag A"; description = 'A student club workshop.'
    location = "Lab $runTag"; startTimeUtc = '2024-12-05T17:00:00+04:00'
    endTimeUtc = '2024-12-05T19:00:00+04:00'; capacity = 30
    expectedAttendance = 10; status = 'Published'
}

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Invoke-Test([string]$Name, [scriptblock]$Action) {
    $script:testCount++
    try {
        & $Action
        Write-Host "PASS: $Name"
    } catch {
        $failures.Add("${Name}: $($_.Exception.Message)")
        Write-Host "FAIL: $Name - $($_.Exception.Message)"
    }
}

function New-Body([string]$Field = '', $Value = $null, [switch]$Remove) {
    $copy = [ordered]@{}
    foreach ($entry in $valid.GetEnumerator()) { $copy[$entry.Key] = $entry.Value }
    if ($Remove) { $copy.Remove($Field) } elseif ($Field) { $copy[$Field] = $Value }
    return ConvertTo-Json -InputObject $copy -Depth 10 -Compress
}

function Send-Request(
    [string]$Method, [string]$Path, [int[]]$ExpectedStatus,
    [string]$Body = '', [string]$Authorization = $userA, [string]$Field = ''
) {
    # HttpWebRequest exposes non-2xx responses on Windows PowerShell 5.1 too.
    $request = [System.Net.HttpWebRequest]::Create("$BaseUrl$Path")
    $request.Method = $Method
    $request.Timeout = 15000
    $request.AllowAutoRedirect = $false
    if ($Authorization) { $request.Headers['Authorization'] = $Authorization }
    if ($Method -in @('POST', 'PUT', 'PATCH')) {
        $request.ContentType = 'application/json'
        $bytes = [Text.Encoding]::UTF8.GetBytes($Body)
        $request.ContentLength = $bytes.Length
        if ($bytes.Length -gt 0) {
            $stream = $request.GetRequestStream()
            try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
        }
    }
    try { $response = $request.GetResponse() } catch [System.Net.WebException] {
        $response = $_.Exception.Response
        if ($null -eq $response) { throw "Cannot reach $BaseUrl : $($_.Exception.Message)" }
    }
    try {
        $reader = [IO.StreamReader]::new($response.GetResponseStream())
        try { $raw = $reader.ReadToEnd() } finally { $reader.Dispose() }
        $status = [int]$response.StatusCode
        $headers = $response.Headers
    } finally { $response.Dispose() }
    $script:requestCount++
    $json = if ($raw) { $raw | ConvertFrom-Json } else { $null }
    # Track even an unexpectedly accepted POST so a failed test can still clean up.
    if ($Method -eq 'POST' -and $status -eq 201 -and $null -ne $json.data.id) {
        [void]$createdIds.Add([int]$json.data.id)
    }
    Assert-True ($status -in $ExpectedStatus) "$Method $Path expected HTTP $($ExpectedStatus -join '/'), got $status. Response: $raw"
    if ($Method -eq 'HEAD') {
        Assert-True ([string]::IsNullOrEmpty($raw)) 'HEAD returned a response body.'
    } else {
        Assert-True ($headers['Content-Type'] -match 'application/json') "$Method $Path did not return JSON."
        if ($status -ge 400) {
            Assert-True ($json.success -eq $false -and @($json.PSObject.Properties.Name).Count -eq 2 -and $null -ne $json.error) 'Invalid error envelope.'
            $code = switch ($status) {
                400 { 'VALIDATION_ERROR' }; 401 { 'UNAUTHORIZED' }; 403 { 'FORBIDDEN' }
                404 { 'NOT_FOUND' }; 405 { 'METHOD_NOT_ALLOWED' }; 409 { 'CONFLICT' }
            }
            Assert-True ($json.error.code -ceq $code) "Expected $code, got $($json.error.code)."
            Assert-True (-not [string]::IsNullOrWhiteSpace($json.error.message)) 'Error message is missing.'
            if ($status -eq 400) {
                Assert-True ($json.error.message -ceq 'The request contains invalid or missing fields.' -and @($json.error.PSObject.Properties.Name).Count -eq 3) 'Invalid validation envelope.'
                Assert-True ($raw -match '"details"\s*:\s*\[' -and $json.error.details.Count -gt 0) 'Validation details must be a nonempty array.'
                foreach ($detail in $json.error.details) {
                    Assert-True (@($detail.PSObject.Properties.Name).Count -eq 2 -and $detail.field -cmatch '^[a-z][a-zA-Z0-9]*$' -and -not [string]::IsNullOrWhiteSpace($detail.message)) 'Invalid validation field detail.'
                }
                if ($Field) { Assert-True ($json.error.details.field -ccontains $Field) "Missing detail for $Field." }
            } else {
                Assert-True (@($json.error.PSObject.Properties.Name).Count -eq 2 -and $null -eq $json.error.PSObject.Properties['details']) 'Only validation errors may contain details.'
                $message = switch ($status) {
                    401 { 'Authentication is required.' }
                    403 { 'You do not have permission to access this event.' }
                    404 { 'Event not found.' }
                    405 { 'The HTTP method is not allowed for this resource.' }
                    409 { 'An event with the same title, location and start time already exists.' }
                }
                Assert-True ($json.error.message -ceq $message) "Incorrect $status message."
            }
            Assert-True ($raw -notmatch 'StackTrace|System\.|JsonException|BytePosition') 'Internal exception details leaked.'
        } else {
            Assert-True ($json.success -eq $true -and -not [string]::IsNullOrWhiteSpace($json.message) -and $null -ne $json.PSObject.Properties['data'] -and $null -eq $json.PSObject.Properties['error']) 'Invalid success envelope.'
            if ($status -eq 201) { Assert-True ($headers['Location'] -ceq "$BaseUrl/api/v1/events/$($json.data.id)") 'Incorrect Location header.' }
            if ($Method -eq 'DELETE') { Assert-True ($null -eq $json.data) 'DELETE must return data=null.' }
        }
    }
    if ($status -eq 401) { Assert-True ($headers['WWW-Authenticate'] -ceq 'Bearer') 'Missing bearer challenge.' }
    if ($status -eq 405) {
        $expectedAllow = if ($Path -eq '/api/v1/events') { 'GET,POST' } else { 'DELETE,GET,PUT' }
        $allow = (($headers['Allow'] -split '[,\s]+' | Where-Object { $_ } | Sort-Object) -join ',')
        Assert-True ($allow -ceq $expectedAllow) "Incorrect Allow header: $allow (expected $expectedAllow)."
    }
    return [pscustomobject]@{ Json = $json; Body = $raw; Status = $status }
}

function Get-Events([string]$Authorization) {
    $items = [System.Collections.Generic.List[object]]::new()
    $page = 1
    do {
        $response = Send-Request GET "/api/v1/events?page=$page&perPage=100" 200 '' $Authorization
        Assert-True ($response.Json.meta.page -eq $page -and $response.Json.meta.perPage -eq 100) 'Invalid list metadata.'
        foreach ($item in $response.Json.data) { $items.Add($item) }
        Assert-True ($items.Count -ge $response.Json.meta.total -or $response.Json.data.Count -gt 0) 'Pagination ended before the accessible total.'
        $page++
    } while ($items.Count -lt $response.Json.meta.total)
    Assert-True ($items.Count -eq $response.Json.meta.total) 'List total does not match accessible data.'
    return $items.ToArray()
}

$baseline = $null
try {
    $baseline = @(Get-Events $admin) | ConvertTo-Json -Depth 10
    $body = New-Body
    $first = Send-Request POST '/api/v1/events' 201 $body
    $secondBody = New-Body title "Validation $runTag B"
    $second = Send-Request POST '/api/v1/events' 201 $secondBody
    $otherOwner = Send-Request POST '/api/v1/events' 201 $body $userB
    $firstId = $first.Json.data.id
    $secondId = $second.Json.data.id
    $otherId = $otherOwner.Json.data.id

    Invoke-Test 'Valid POST uses authenticated ownership and UTC, including past dates' {
        Assert-True ($first.Json.data.ownerId -ceq 'user-a') 'Created event has the wrong owner.'
        Assert-True ($first.Body -match '"startTimeUtc":"2024-12-05T13:00:00\+00:00"' -and $first.Body -match '"endTimeUtc":"2024-12-05T15:00:00\+00:00"') 'UTC normalization changed.'
    }
    Invoke-Test 'Different owners can create identical events' {
        Assert-True ($otherOwner.Json.data.ownerId -ceq 'user-b' -and $otherId -ne $firstId) 'Different-owner creation failed.'
    }

    $cases = [System.Collections.Generic.List[object]]::new()
    foreach ($field in @('title','description','location','startTimeUtc','endTimeUtc','capacity')) {
        $cases.Add(@{ Name = "Missing $field"; Field = $field; Body = (New-Body $field $null -Remove) })
        $cases.Add(@{ Name = "Null $field"; Field = $field; Body = (New-Body $field $null) })
    }
    foreach ($field in @('title','description','location')) {
        foreach ($value in @('', '   ', [string][char]9)) { $cases.Add(@{ Name = "Blank $field"; Field = $field; Body = (New-Body $field $value) }) }
        foreach ($value in @(42, $true, @('text'), @{ value = 'text' })) { $cases.Add(@{ Name = "Wrong JSON type for $field"; Field = $field; Body = (New-Body $field $value) }) }
    }
    foreach ($length in @(@{ Field = 'title'; Value = 'ab' }, @{ Field = 'title'; Value = ('x' * 101) }, @{ Field = 'description'; Value = ('x' * 1001) }, @{ Field = 'location'; Value = ('x' * 151) })) {
        $cases.Add(@{ Name = "Invalid length for $($length.Field)"; Field = $length.Field; Body = (New-Body $length.Field $length.Value) })
    }
    foreach ($field in @('startTimeUtc','endTimeUtc')) {
        foreach ($value in @('not-a-date', '2026-02-30T13:00:00Z', 42, @{})) { $cases.Add(@{ Name = "Invalid $field"; Field = $field; Body = (New-Body $field $value) }) }
    }
    foreach ($end in @('2024-12-05T13:00:00Z','2024-12-05T12:00:00Z','2024-12-05T15:00:00+02:00')) { $cases.Add(@{ Name = 'End must be later than start'; Field = 'endTimeUtc'; Body = (New-Body endTimeUtc $end) }) }
    foreach ($value in @(0, -1, 1.5, '30', $true)) { $cases.Add(@{ Name = 'Invalid capacity'; Field = 'capacity'; Body = (New-Body capacity $value) }) }
    foreach ($value in @(-1, 1.5, '10', $null)) { $cases.Add(@{ Name = 'Invalid expected attendance'; Field = 'expectedAttendance'; Body = (New-Body expectedAttendance $value) }) }
    foreach ($value in @('Unknown', '1', 1, 99, $null, 'Draft, Published')) { $cases.Add(@{ Name = 'Invalid status'; Field = 'status'; Body = (New-Body status $value) }) }
    foreach ($raw in @('{}', '{', 'null', '', '[]', '"event"')) { $cases.Add(@{ Name = 'Malformed or invalid JSON body'; Field = ''; Body = $raw }) }
    foreach ($case in $cases) {
        foreach ($method in @('POST','PUT')) {
            $path = if ($method -eq 'POST') { '/api/v1/events' } else { "/api/v1/events/$secondId" }
            Invoke-Test "$method $($case.Name)" { $null = Send-Request $method $path 400 $case.Body $userA $case.Field }
        }
    }

    foreach ($duplicate in @($body, (New-Body title "  VALIDATION $runTag A  ").Replace("Lab $runTag", "  LAB $runTag  "), (New-Body startTimeUtc '2024-12-05T13:00:00Z'))) {
        Invoke-Test 'Duplicate POST returns 409 without details' { $null = Send-Request POST '/api/v1/events' 409 $duplicate }
        Invoke-Test 'Duplicate PUT returns 409 without details' { $null = Send-Request PUT "/api/v1/events/$secondId" 409 $duplicate }
    }
    Invoke-Test 'Rejected writes preserve both existing events and ID allocation' {
        $readFirst = Send-Request GET "/api/v1/events/$firstId" 200
        $readSecond = Send-Request GET "/api/v1/events/$secondId" 200
        Assert-True (($readFirst.Json.data | ConvertTo-Json -Depth 10) -ceq ($first.Json.data | ConvertTo-Json -Depth 10)) 'Rejected request changed the first event.'
        Assert-True (($readSecond.Json.data | ConvertTo-Json -Depth 10) -ceq ($second.Json.data | ConvertTo-Json -Depth 10)) 'Rejected request changed the second event.'
        $next = Send-Request POST '/api/v1/events' 201 (New-Body title "Validation $runTag ID check")
        Assert-True ($next.Json.data.id -eq ($otherId + 1)) 'Rejected requests consumed an ID.'
    }
    Invoke-Test 'PUT does not conflict with itself and persists all editable fields' {
        $updatedBody = $body.Replace('A student club workshop.', 'Updated workshop.').Replace('"capacity":30', '"capacity":40').Replace('"expectedAttendance":10', '"expectedAttendance":25').Replace('"Published"', '"Cancelled"')
        $updated = Send-Request PUT "/api/v1/events/$firstId" 200 $updatedBody
        Assert-True ($updated.Json.data.id -eq $firstId -and $updated.Json.data.ownerId -ceq 'user-a' -and $updated.Json.data.title -ceq $valid.title -and $updated.Json.data.location -ceq $valid.location -and $updated.Json.data.description -ceq 'Updated workshop.' -and $updated.Json.data.capacity -eq 40 -and $updated.Json.data.expectedAttendance -eq 25 -and $updated.Json.data.status -ceq 'Cancelled') 'PUT did not preserve identity or update the editable fields.'
        $read = Send-Request GET "/api/v1/events/$firstId" 200
        Assert-True (($read.Json.data | ConvertTo-Json -Depth 10) -ceq ($updated.Json.data | ConvertTo-Json -Depth 10)) 'PUT did not persist.'
    }
    Invoke-Test 'Administrator follows the original owner duplicate rule' { $null = Send-Request PUT "/api/v1/events/$secondId" 409 $body $admin }
    Invoke-Test 'Defaults remain attendance 0 and Draft for POST and PUT' {
        $defaults = [ordered]@{}
        foreach ($entry in $valid.GetEnumerator()) { if ($entry.Key -notin @('expectedAttendance','status')) { $defaults[$entry.Key] = $entry.Value } }
        $defaults.title = "Validation $runTag defaults"
        $defaultsBody = $defaults | ConvertTo-Json -Compress
        $created = Send-Request POST '/api/v1/events' 201 $defaultsBody
        $updated = Send-Request PUT "/api/v1/events/$($created.Json.data.id)" 200 $defaultsBody
        foreach ($result in @($created, $updated)) { Assert-True ($result.Json.data.expectedAttendance -eq 0 -and $result.Json.data.status -ceq 'Draft') 'Optional defaults changed.' }
    }
    Invoke-Test 'Maximum string lengths and case-insensitive status are accepted' {
        $boundary = [ordered]@{}
        foreach ($entry in $valid.GetEnumerator()) { $boundary[$entry.Key] = $entry.Value }
        $boundary.title = $runTag.PadRight(100, 'x'); $boundary.description = 'x' * 1000; $boundary.location = 'x' * 150; $boundary.status = 'pUbLiShEd'
        $created = Send-Request POST '/api/v1/events' 201 ($boundary | ConvertTo-Json -Compress)
        Assert-True ($created.Json.data.status -ceq 'Published') 'Status output spelling changed.'
    }
    Invoke-Test 'Body-supplied identity and role cannot transfer ownership' {
        $spoof = $secondBody.TrimEnd('}') + ',"id":999,"ownerId":"user-b","role":"Administrator"}'
        $updated = Send-Request PUT "/api/v1/events/$secondId" 200 $spoof
        Assert-True ($updated.Json.data.id -eq $secondId -and $updated.Json.data.ownerId -ceq 'user-a') 'PUT transferred identity.'
    }
    foreach ($identity in @(@{ Header = $userA; Foreign = $otherId }, @{ Header = $userB; Foreign = $firstId })) {
        foreach ($method in @('GET','PUT','DELETE')) {
            Invoke-Test "$method cannot access another owner's event" { $null = Send-Request $method "/api/v1/events/$($identity.Foreign)" 403 $body $identity.Header }
        }
    }
    foreach ($endpoint in @(@{ Method = 'GET'; Path = '/api/v1/events' }, @{ Method = 'GET'; Path = "/api/v1/events/$firstId" }, @{ Method = 'POST'; Path = '/api/v1/events' }, @{ Method = 'PUT'; Path = "/api/v1/events/$firstId" }, @{ Method = 'DELETE'; Path = "/api/v1/events/$firstId" })) {
        foreach ($authorization in @('', 'Bearer invalid-token')) { Invoke-Test "$($endpoint.Method) rejects missing/invalid token" { $null = Send-Request $endpoint.Method $endpoint.Path 401 '{' $authorization } }
    }
    foreach ($method in @('GET','PUT','DELETE')) { Invoke-Test "$method nonexistent event returns 404" { $null = Send-Request $method '/api/v1/events/2147483647' 404 $body } }
    foreach ($method in @('PUT','DELETE','PATCH','OPTIONS','HEAD')) { Invoke-Test "$method collection returns 405 with Allow" { $null = Send-Request $method '/api/v1/events' 405 } }
    foreach ($method in @('POST','PATCH','OPTIONS','HEAD')) { Invoke-Test "$method resource returns 405 with Allow" { $null = Send-Request $method "/api/v1/events/$firstId" 405 $body } }
    Invoke-Test 'Regular lists contain only owned events and administrator sees all owners' {
        $a = @(Get-Events $userA); $b = @(Get-Events $userB); $all = @(Get-Events $admin)
        Assert-True (@($a | Where-Object ownerId -ne 'user-a').Count -eq 0 -and $a.id -contains $firstId) 'User A list leaked events.'
        Assert-True (@($b | Where-Object ownerId -ne 'user-b').Count -eq 0 -and $b.id -contains $otherId) 'User B list leaked events.'
        Assert-True ($all.id -contains $firstId -and $all.id -contains $otherId) 'Administrator cannot list all owners.'
    }
    Invoke-Test 'Administrator can retrieve and update another owner event' {
        $null = Send-Request GET "/api/v1/events/$otherId" 200 '' $admin
        $updated = Send-Request PUT "/api/v1/events/$otherId" 200 (New-Body title "Validation $runTag admin update") $admin
        Assert-True ($updated.Json.data.ownerId -ceq 'user-b') 'Administrator update changed the owner.'
    }
    Invoke-Test 'Regular DELETE and subsequent GET work' {
        $null = Send-Request DELETE "/api/v1/events/$secondId" 200
        $null = Send-Request GET "/api/v1/events/$secondId" 404
    }
    Invoke-Test 'Administrator can delete another owner event' {
        $null = Send-Request DELETE "/api/v1/events/$otherId" 200 '' $admin
        $null = Send-Request GET "/api/v1/events/$otherId" 404 '' $admin
    }
} catch {
    $failures.Add("Setup or execution: $($_.Exception.Message)")
} finally {
    foreach ($id in @($createdIds)) {
        try { $null = Send-Request DELETE "/api/v1/events/$id" @(200,404) '' $admin } catch {
            $failures.Add("Cleanup event ${id}: $($_.Exception.Message)")
        }
    }
}
if ($null -ne $baseline) {
    Invoke-Test 'Cleanup preserves all pre-existing data' {
        $after = @(Get-Events $admin) | ConvertTo-Json -Depth 10
        Assert-True ($after -ceq $baseline) 'Test events remain or pre-existing events changed.'
    }
}
if ($failures.Count -gt 0) {
    Write-Host "FAIL: $($failures.Count) failure(s), $script:testCount cases, $script:requestCount HTTP requests."
    foreach ($failure in $failures) { Write-Host " - $failure" }
    exit 1
}
Write-Host "PASS: $script:testCount cases, $script:requestCount HTTP requests; all test-created events cleaned up."
exit 0
