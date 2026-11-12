# Stage 4 authentication and authorization verification

Verified on 2026-11-12 against `http://localhost:5024` with actual HTTP requests.
`dotnet restore` and `dotnet build` passed with zero warnings and zero errors.
All 109 scripted HTTP checks passed. The API was stopped after verification.

## Reproduce the checks

Use PowerShell 7.5 or later for the test script. Start a fresh API process so the
store contains only its four initial events:

```powershell
dotnet restore
dotnet build
dotnet run --project src/ClubFlow.Api --no-build --no-restore
```

From another terminal at the repository root:

```powershell
./scripts/Test-EventAuthentication.ps1
```

This executes 101 requests and deliberately leaves modified, deleted, and created
events in memory. Stop the API with Ctrl+C and start it again with the same run
command. Then execute the remaining eight restart checks:

```powershell
./scripts/Test-EventAuthentication.ps1 -AfterRestart
```

The script fails immediately if a status, envelope, or data assertion fails.
Exact method, path, Authorization header, JSON body, and observed status for each
request are written to `src/ClubFlow.Api/obj/event-auth-http-results.json`.
The initial seed snapshot is in `src/ClubFlow.Api/obj/event-auth-seed.json`.
Both files are ignored build artifacts. The script accepts `-BaseUrl` for another
local address. Run the first phase only against a fresh process.

## Results

| Observed HTTP status | Request count |
| --- | --- |
| 200 | 42 |
| 201 | 6 |
| 400 | 7 |
| 401 | 31 |
| 403 | 9 |
| 404 | 14 |
| Total | 109 |

| Behavior | Verified result |
| --- | --- |
| All five endpoints without credentials | 401 with the exact `UNAUTHORIZED` JSON envelope and `WWW-Authenticate: Bearer` |
| Invalid token, missing bearer parameter, Basic scheme, extra token text, and combined credentials | 401 on all five endpoints |
| Authentication before body parsing | Unauthenticated POST/PUT with malformed JSON still return 401 |
| Header/token case handling | Lowercase `bearer` works; altered token case is rejected |
| Initial User A / User B lists | IDs 1,2 / 3,4 respectively; each has total 2 |
| Initial administrator list | IDs 1,2,3,4; total 4 |
| Filter before pagination | User A page 2/perPage 1 returns ID 2; User B returns ID 4; totals remain 2 |
| Administrator pagination | Page 2/perPage 2 returns IDs 3,4 with total 4 |
| Empty and very large pages | Empty array with the accessible total; no overflow |
| Own-event and administrator reads | 200 with the existing success envelope |
| Both regular users' cross-owner GET/PUT/DELETE | 403 with the exact `FORBIDDEN` envelope; seed data remains unchanged |
| Missing IDs for all three users | GET/PUT/DELETE return 404 with the existing `NOT_FOUND` envelope |
| Creation by each identity | Owner is user-a, user-b, or admin based on the token; 201, generated ID, and correct Location header |
| Body-supplied ID, owner, and role | Ignored; no identity change or administrator privileges |
| Lists after creation | Each regular user sees only their events; administrator sees all eight |
| Own-event PUT and administrator PUT of foreign events | All editable properties persist; ID and original OwnerId remain unchanged; timestamps normalize to UTC |
| Own-event DELETE and administrator DELETE of foreign events | 200 with `data: null`; subsequent GET returns 404 |
| Unrelated events after successful CRUD | Exactly match the original seed data |
| Existing malformed JSON, enum, and pagination errors | Existing 400 envelopes and codes preserved |
| Restart | Restores the exact original four events, including modified/deleted seed events; removes created ID 9; filtered totals return to 2 each |
| ID allocation after restart | Next created event has ID 5 and owner admin |

The exact 401 message is `Authentication is required.` The exact 403 message is
`You do not have permission to access this event.` Error envelopes contain only
`success` and `error`, with only `code` and `message` inside `error`. Successful
envelopes retain `success`, `message`, `data`, and list-only `meta`.

The sandbox initially blocked the local socket and ASP.NET Core's user-level
Data Protection key initialization; the approved verification run outside the
sandbox resolved both. The test client was configured to send malformed headers
without rejecting them locally. No application test failures remain.

## Implementation review boundaries

The uncommitted changes can later be organized into approximately three commits:

1. Mock authentication: handler token/claim logic, middleware registration, and
   authentication requirement on the Events controller.
2. Ownership authorization: filtered reads, backend access checks, claim-derived
   creation ownership, and removal of OwnerId from CreateEventRequest.
3. Authentication/permission errors: handler challenge/forbidden JSON overrides,
   verification script, and documentation.

EventStore, its locking behavior, event models, and the shared response types were
left unchanged. No packages, login endpoints, database, detailed event validation,
or HTML page were added. No commits or Git identity changes were made.
