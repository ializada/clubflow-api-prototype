#Requires -Version 5.1
param(
    [string]$BaseUrl = 'http://localhost:5024',
    [switch]$AfterRestart
)

$ErrorActionPreference = 'Stop'
$artifactDirectory = Join-Path $PSScriptRoot '../src/ClubFlow.Api/obj'
$seedPath = Join-Path $artifactDirectory 'event-auth-seed.json'
$resultsPath = Join-Path $artifactDirectory 'event-auth-http-results.json'
$results = [System.Collections.Generic.List[object]]::new()
$userA = 'Bearer user-a-token'
$userB = 'Bearer user-b-token'
$admin = 'Bearer admin-token'
$jsonParameters = @{}
if ((Get-Command ConvertFrom-Json).Parameters.ContainsKey('DateKind')) {
    $jsonParameters.DateKind = 'String'
}

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Send-Request(
    [string]$Name, [string]$Method, [string]$Path, [int]$ExpectedStatus,
    [string]$Authorization = $admin, [string]$Body = ''
) {
    # This transport also reads error responses on Windows PowerShell 5.1.
    $request = [System.Net.HttpWebRequest]::Create("$BaseUrl$Path")
    $request.Method = $Method
    $request.Timeout = 10000
    $request.AllowAutoRedirect = $false
    if ($Authorization) { $request.Headers['Authorization'] = $Authorization }
    if ($Body) {
        $request.ContentType = 'application/json'
        $bytes = [Text.Encoding]::UTF8.GetBytes($Body)
        $request.ContentLength = $bytes.Length
        $stream = $request.GetRequestStream()
        try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
    }
    try { $webResponse = $request.GetResponse() } catch [System.Net.WebException] {
        $webResponse = $_.Exception.Response
        if ($null -eq $webResponse) { throw }
    }
    try {
        $reader = [IO.StreamReader]::new($webResponse.GetResponseStream())
        try { $content = $reader.ReadToEnd() } finally { $reader.Dispose() }
        $response = [pscustomobject]@{
            StatusCode = [int]$webResponse.StatusCode
            Content = $content
            Headers = $webResponse.Headers
        }
    } finally { $webResponse.Dispose() }
    Assert-True ($response.StatusCode -eq $ExpectedStatus) "$Name expected $ExpectedStatus, got $($response.StatusCode): $($response.Content)"
    Assert-True (([string]$response.Headers['Content-Type']) -match 'application/json') "$Name did not return JSON."
    $json = $response.Content | ConvertFrom-Json @jsonParameters

    if ($ExpectedStatus -ge 400) {
        Assert-True ($json.success -eq $false -and @($json.PSObject.Properties.Name).Count -eq 2 -and $null -ne $json.error) "$Name has an invalid error envelope."
        if ($ExpectedStatus -eq 400 -and $json.error.code -ceq 'VALIDATION_ERROR') {
            Assert-True (@($json.error.PSObject.Properties.Name).Count -eq 3 -and $json.error.message -ceq 'The request contains invalid or missing fields.') "$Name has an incorrect validation envelope."
            Assert-True ($json.error.details.Count -gt 0) "$Name is missing validation details."
            foreach ($detail in $json.error.details) {
                Assert-True (@($detail.PSObject.Properties.Name).Count -eq 2 -and -not [string]::IsNullOrWhiteSpace($detail.field) -and -not [string]::IsNullOrWhiteSpace($detail.message)) "$Name has invalid field details."
            }
        } else {
            Assert-True (@($json.error.PSObject.Properties.Name).Count -eq 2 -and $null -eq $json.error.PSObject.Properties['details']) "$Name leaked extra error details."
        }
        switch ($ExpectedStatus) {
            401 {
                Assert-True ($json.error.code -ceq 'UNAUTHORIZED' -and $json.error.message -ceq 'Authentication is required.') "$Name has an incorrect 401 envelope."
                Assert-True (([string]$response.Headers['WWW-Authenticate']) -ceq 'Bearer') "$Name is missing the bearer challenge."
            }
            403 { Assert-True ($json.error.code -ceq 'FORBIDDEN' -and $json.error.message -ceq 'You do not have permission to access this event.') "$Name has an incorrect 403 envelope." }
            404 { Assert-True ($json.error.code -ceq 'NOT_FOUND' -and $json.error.message -ceq 'Event not found.') "$Name has an incorrect 404 envelope." }
        }
    } else {
        Assert-True ($json.success -eq $true -and $null -ne $json.message -and $null -ne $json.PSObject.Properties['data'] -and $null -eq $json.PSObject.Properties['error']) "$Name has an invalid success envelope."
        if ($Method -eq 'DELETE') { Assert-True ($null -eq $json.data) "$Name must return data=null." }
        if ($ExpectedStatus -eq 201) {
            Assert-True (([string]$response.Headers['Location']) -ceq "$BaseUrl/api/v1/events/$($json.data.id)") "$Name has an incorrect Location header."
        }
    }

    $results.Add([pscustomobject]@{
        Name = $Name; Method = $Method; Path = $Path
        Authorization = $Authorization; Body = $Body; Status = [int]$response.StatusCode
    })
    Write-Host "$Name`: $Method $Path -> $($response.StatusCode)"
    return $json
}

$createBody = '{"title":"Student API Workshop","description":"Build and test an API with the Programming Club.","location":"Engineering Lab 204","startTimeUtc":"2026-12-05T13:00:00Z","endTimeUtc":"2026-12-05T15:00:00Z","capacity":30,"expectedAttendance":24,"status":"Draft"}'
$spoofBody = '{"id":999,"ownerId":"user-b","role":"Administrator","title":"Student API Workshop","description":"Build and test an API with the Programming Club.","location":"Engineering Lab 204","startTimeUtc":"2026-12-05T13:00:00Z","endTimeUtc":"2026-12-05T15:00:00Z","capacity":30,"expectedAttendance":24,"status":"Draft"}'
$updateBody = '{"id":777,"ownerId":"admin","role":"Administrator","title":"Advanced API Workshop","description":"Test HTTP endpoints with the Programming Club.","location":"Engineering Lab 205","startTimeUtc":"2026-12-06T17:00:00+04:00","endTimeUtc":"2026-12-06T19:00:00+04:00","capacity":40,"expectedAttendance":32,"status":"Cancelled"}'

if ($AfterRestart) {
    foreach ($previous in (Get-Content -LiteralPath $resultsPath -Raw | ConvertFrom-Json)) { $results.Add($previous) }
    $seed = Get-Content -LiteralPath $seedPath -Raw | ConvertFrom-Json @jsonParameters
    $restored = Send-Request 'Restart restores original seed' GET '/api/v1/events' 200
    Assert-True (($restored.data | ConvertTo-Json -Depth 10) -ceq ($seed | ConvertTo-Json -Depth 10)) 'Restart did not restore the exact original mock data.'
    foreach ($identity in @(@{ Header = $userA; Owner = 'user-a' }, @{ Header = $userB; Owner = 'user-b' })) {
        $list = Send-Request "Restart list for $($identity.Owner)" GET '/api/v1/events' 200 $identity.Header
        Assert-True ($list.meta.total -eq 2 -and @($list.data | Where-Object ownerId -ne $identity.Owner).Count -eq 0) 'Restart ownership filtering failed.'
    }
    $null = Send-Request 'Restart removes created event' GET '/api/v1/events/9' 404
    $original = Send-Request 'Restart restores modified event' GET '/api/v1/events/1' 200 $userA
    Assert-True ($original.data.title -ceq $seed[0].title) 'Restart did not restore the original title.'
    $null = Send-Request 'Restart restores deleted event' GET '/api/v1/events/2' 200 $userA
    $created = Send-Request 'Restart resets ID allocation' POST '/api/v1/events' 201 $admin $createBody
    Assert-True ($created.data.id -eq 5 -and $created.data.ownerId -ceq 'admin') 'Restart ID allocation or admin ownership failed.'
    $null = Send-Request 'Clean up restart test event' DELETE '/api/v1/events/5' 200
} else {
    $endpoints = @(
        @{ Method = 'GET'; Path = '/api/v1/events'; Body = '' },
        @{ Method = 'GET'; Path = '/api/v1/events/1'; Body = '' },
        @{ Method = 'POST'; Path = '/api/v1/events'; Body = '{' },
        @{ Method = 'PUT'; Path = '/api/v1/events/1'; Body = '{' },
        @{ Method = 'DELETE'; Path = '/api/v1/events/1'; Body = '' }
    )
    foreach ($header in @('', 'Bearer invalid-token', 'Bearer', 'Basic user-a-token', 'Bearer user-a-token extra', 'Bearer user-a-token, Bearer admin-token')) {
        foreach ($endpoint in $endpoints) {
            $null = Send-Request "Reject credentials [$header]" $endpoint.Method $endpoint.Path 401 $header $endpoint.Body
        }
    }

    $a = Send-Request 'User A initial list' GET '/api/v1/events' 200 $userA
    $b = Send-Request 'User B initial list' GET '/api/v1/events' 200 $userB
    $all = Send-Request 'Administrator initial list' GET '/api/v1/events' 200
    Assert-True (($a.data.id -join ',') -eq '1,2' -and $a.meta.total -eq 2 -and $a.meta.page -eq 1 -and $a.meta.perPage -eq 20) 'User A initial data/metadata mismatch.'
    Assert-True (($b.data.id -join ',') -eq '3,4' -and $b.meta.total -eq 2) 'User B initial data/metadata mismatch.'
    Assert-True (($all.data.id -join ',') -eq '1,2,3,4' -and $all.meta.total -eq 4) 'Admin initial data mismatch.'
    $all.data | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $seedPath
    $seedJson = $all.data | ConvertTo-Json -Depth 10

    foreach ($pagination in @(
        @{ Header = $userA; Path = '?page=2&perPage=1'; Ids = '2'; Total = 2 },
        @{ Header = $userB; Path = '?page=2&perPage=1'; Ids = '4'; Total = 2 },
        @{ Header = $admin; Path = '?page=2&perPage=2'; Ids = '3,4'; Total = 4 },
        @{ Header = $userB; Path = '?page=3&perPage=1'; Ids = ''; Total = 2 },
        @{ Header = $userA; Path = '?page=2147483647&perPage=100'; Ids = ''; Total = 2 }
    )) {
        $list = Send-Request 'Filter before pagination' GET "/api/v1/events$($pagination.Path)" 200 $pagination.Header
        Assert-True (($list.data.id -join ',') -eq $pagination.Ids -and $list.meta.total -eq $pagination.Total) 'Filtering or pagination mismatch.'
    }
    $null = Send-Request 'Bearer scheme is case insensitive' GET '/api/v1/events/1' 200 'bearer user-a-token'
    $null = Send-Request 'Tokens remain case sensitive' GET '/api/v1/events' 401 'Bearer USER-A-TOKEN'
    $null = Send-Request 'User A reads own event' GET '/api/v1/events/1' 200 $userA
    $null = Send-Request 'User B reads own event' GET '/api/v1/events/3' 200 $userB
    $null = Send-Request 'Administrator reads User A event' GET '/api/v1/events/1' 200
    $null = Send-Request 'Administrator reads User B event' GET '/api/v1/events/3' 200

    foreach ($denied in @(@{ Header = $userA; Id = 3 }, @{ Header = $userB; Id = 1 })) {
        foreach ($method in @('GET', 'PUT', 'DELETE')) {
            $body = if ($method -eq 'PUT') { $updateBody } else { '' }
            $null = Send-Request 'Deny cross-owner access and role spoofing' $method "/api/v1/events/$($denied.Id)" 403 $denied.Header $body
        }
    }
    foreach ($header in @($userA, $userB, $admin)) {
        foreach ($method in @('GET', 'PUT', 'DELETE')) {
            $body = if ($method -eq 'PUT') { $updateBody } else { '' }
            $null = Send-Request 'Missing event remains 404' $method '/api/v1/events/999999' 404 $header $body
        }
    }
    $unchanged = Send-Request 'Denied operations leave data unchanged' GET '/api/v1/events' 200
    Assert-True (($unchanged.data | ConvertTo-Json -Depth 10) -ceq $seedJson) 'Denied operations modified data.'

    $createdA = Send-Request 'User A creates without owner' POST '/api/v1/events' 201 $userA $createBody
    $spoofedA = Send-Request 'User A cannot spoof owner or role' POST '/api/v1/events' 201 $userA ($spoofBody -replace 'Student API Workshop', 'Student API Workshop ownership check')
    $createdB = Send-Request 'User B cannot spoof owner' POST '/api/v1/events' 201 $userB ($spoofBody -replace '"user-b"', '"user-a"')
    $createdAdmin = Send-Request 'Administrator creates as admin' POST '/api/v1/events' 201 $admin $spoofBody
    Assert-True ($createdA.data.id -eq 5 -and $createdA.data.ownerId -ceq 'user-a' -and $spoofedA.data.id -eq 6 -and $spoofedA.data.ownerId -ceq 'user-a') 'User A identity or ID allocation failed.'
    Assert-True ($createdB.data.id -eq 7 -and $createdB.data.ownerId -ceq 'user-b' -and $createdAdmin.data.id -eq 8 -and $createdAdmin.data.ownerId -ceq 'admin') 'User B/admin identity or ID allocation failed.'
    foreach ($identity in @(
        @{ Header = $userA; Ids = '1,2,5,6'; Total = 4 },
        @{ Header = $userB; Ids = '3,4,7'; Total = 3 },
        @{ Header = $admin; Ids = '1,2,3,4,5,6,7,8'; Total = 8 }
    )) {
        $list = Send-Request 'Created events appear only in accessible lists' GET '/api/v1/events' 200 $identity.Header
        Assert-True (($list.data.id -join ',') -eq $identity.Ids -and $list.meta.total -eq $identity.Total) 'Created event list mismatch.'
    }
    $null = Send-Request 'Spoofed administrator role grants no access' GET '/api/v1/events/3' 403 $userA
    $null = Send-Request 'User B cannot read User A new event' GET '/api/v1/events/6' 403 $userB
    $null = Send-Request 'User A cannot read admin event' GET '/api/v1/events/8' 403 $userA
    $null = Send-Request 'Administrator reads new regular event' GET '/api/v1/events/6' 200

    foreach ($update in @(
        @{ Header = $userA; Id = 5; Owner = 'user-a' },
        @{ Header = $userB; Id = 7; Owner = 'user-b' },
        @{ Header = $admin; Id = 6; Owner = 'user-a' },
        @{ Header = $admin; Id = 7; Owner = 'user-b' },
        @{ Header = $admin; Id = 8; Owner = 'admin' }
    )) {
        $expectedTitle = "Advanced API Workshop $($update.Id)"
        $eventUpdateBody = $updateBody -replace 'Advanced API Workshop', $expectedTitle
        $updated = Send-Request 'Authorized PUT preserves identity' PUT "/api/v1/events/$($update.Id)" 200 $update.Header $eventUpdateBody
        Assert-True ($updated.data.id -eq $update.Id -and $updated.data.ownerId -ceq $update.Owner) 'PUT transferred identity.'
        Assert-True ($updated.data.title -ceq $expectedTitle -and $updated.data.description -ceq 'Test HTTP endpoints with the Programming Club.' -and $updated.data.location -ceq 'Engineering Lab 205' -and $updated.data.capacity -eq 40 -and $updated.data.expectedAttendance -eq 32 -and $updated.data.status -ceq 'Cancelled' -and $updated.data.startTimeUtc -ceq '2026-12-06T13:00:00+00:00' -and $updated.data.endTimeUtc -ceq '2026-12-06T15:00:00+00:00') 'PUT changed editable field or UTC behavior.'
        $read = Send-Request 'Updated event persists' GET "/api/v1/events/$($update.Id)" 200 $update.Header
        Assert-True (($read.data | ConvertTo-Json -Depth 10) -ceq ($updated.data | ConvertTo-Json -Depth 10)) 'PUT did not persist.'
    }
    foreach ($delete in @(
        @{ Header = $userA; Id = 5 }, @{ Header = $userB; Id = 7 },
        @{ Header = $admin; Id = 6 }, @{ Header = $admin; Id = 8 }
    )) {
        $null = Send-Request 'Authorized DELETE' DELETE "/api/v1/events/$($delete.Id)" 200 $delete.Header
        $null = Send-Request 'Deleted event is gone' GET "/api/v1/events/$($delete.Id)" 404 $delete.Header
    }
    $unchanged = Send-Request 'CRUD did not affect unrelated seed events' GET '/api/v1/events' 200
    Assert-True (($unchanged.data | ConvertTo-Json -Depth 10) -ceq $seedJson) 'CRUD modified unrelated events.'

    foreach ($path in @('?page=0', '?perPage=0', '?perPage=101')) {
        $bad = Send-Request 'Existing pagination error preserved' GET "/api/v1/events$path" 400 $userA
        Assert-True ($bad.error.code -ceq 'INVALID_PAGINATION') 'Pagination error changed.'
    }
    foreach ($body in @('{', 'null', ($createBody -replace '"Draft"', '"Unknown"'), ($createBody -replace '"Draft"', '1'))) {
        $bad = Send-Request 'Existing JSON error preserved' POST '/api/v1/events' 400 $userA $body
        Assert-True ($bad.error.code -ceq 'VALIDATION_ERROR') 'Expected a VALIDATION_ERROR for malformed JSON or an invalid enum.'
    }
    $null = Send-Request 'Modify seed before restart' PUT '/api/v1/events/1' 200 $userA $updateBody
    $null = Send-Request 'Administrator deletes foreign seed before restart' DELETE '/api/v1/events/2' 200
    $created = Send-Request 'Create event before restart' POST '/api/v1/events' 201 $userB $createBody
    Assert-True ($created.data.id -eq 9 -and $created.data.ownerId -ceq 'user-b') 'IDs reused before restart.'
    $modified = Send-Request 'Confirm modified state before restart' GET '/api/v1/events' 200
    Assert-True (($modified.data.id -join ',') -eq '1,3,4,9' -and $modified.data[0].title -ceq 'Advanced API Workshop') 'Missing pre-restart mutations.'
}

$results.ToArray() | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $resultsPath
Write-Host "PASS: $($results.Count) HTTP checks. Results: $resultsPath"
if (-not $AfterRestart) { Write-Host 'Restart the server, then rerun this script with -AfterRestart.' }
