# Event validation and conflict verification

Stage 5 checks verified on 2026-11-12. The API implementation is unchanged by this
tests-and-documentation stage.

## Request rules

POST and PUT use the same rules:

| Field | Rule | When omitted |
| --- | --- | --- |
| `title` | Required, nonblank, 3-100 characters | 400 |
| `description` | Required, nonblank, at most 1000 characters | 400 |
| `location` | Required, nonblank, at most 150 characters | 400 |
| `startTimeUtc`, `endTimeUtc` | Required valid timestamps; end must be strictly later | 400 |
| `capacity` | Required positive integer | 400 |
| `expectedAttendance` | Nonnegative integer | 0 |
| `status` | `Draft`, `Published`, or `Cancelled`; case-insensitive input | `Draft` |

Explicit nulls are rejected, including for attendance and status. Numeric strings,
fractions for integer fields, malformed JSON, and unsupported enum values are
rejected. Times are stored and returned in UTC; past dates are allowed. OwnerId
comes from authentication, and an update preserves the original owner and ID.

ASP.NET Core model validation and JSON parsing failures return HTTP 400 using
safe field messages and canonical camelCase field names:

```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "The request contains invalid or missing fields.",
    "details": [
      { "field": "capacity", "message": "Capacity must be a positive integer." }
    ]
  }
}
```

## Duplicate events and HTTP errors

An owner cannot have two events with the same title, location, and start-time
instant. Title and location comparisons ignore case and surrounding whitespace.
PUT excludes its own ID; an administrator updating another user's event follows
that original owner's duplicate rule. Different owners may have identical events.

Checking and writing happen together under EventStore's lock. A rejected duplicate
does not change existing data or consume a new ID. HTTP 409 responses are:

```json
{
  "success": false,
  "error": {
    "code": "CONFLICT",
    "message": "An event with the same title, location and start time already exists."
  }
}
```

Only validation errors include `details`. Missing/invalid credentials remain 401
`UNAUTHORIZED`; ownership violations remain 403 `FORBIDDEN`; nonexistent IDs
remain 404 `NOT_FOUND`. Unsupported methods return 405 `METHOD_NOT_ALLOWED` in
the JSON envelope, preserving the Allow header (`GET, POST` for the collection;
`GET, PUT, DELETE` for a resource, with header order unspecified). HEAD retains
the status and headers but has no response body.

## Run the checks

From the repository root, start a fresh backend:

```powershell
dotnet restore
dotnet build
dotnet run --project src/ClubFlow.Api
```

In another PowerShell 7.5+ terminal:

```powershell
.\scripts\Test-EventAuthentication.ps1 -BaseUrl http://localhost:5024
```

The authentication script expects the four original events and initial ID
allocation. Its first phase deliberately changes seed data. Stop and restart the
backend with the same run command, then run:

```powershell
.\scripts\Test-EventAuthentication.ps1 -AfterRestart -BaseUrl http://localhost:5024
powershell.exe -NoProfile -File .\scripts\Test-EventValidation.ps1 -BaseUrl http://localhost:5024
```

Run the scripts sequentially against a development instance. Both accept a base
URL and need no external testing packages. The validation script works with
Windows PowerShell 5.1, uses unique titles/locations, and cleans up only events
it created, even after an assertion fails. It verifies pre-existing data is
unchanged and can be rerun without restarting. A failed case is named in its
summary and causes exit code 1. Stop the backend with Ctrl+C when finished.

## Verified results

- Restore and build passed with zero warnings and errors.
- Updated authentication checks passed: 109 HTTP requests across both phases,
  retaining auth, ownership, pagination, CRUD, identity-spoofing, and restart checks.
  Fixtures now avoid accidental same-owner conflicts; malformed writes assert
  `VALIDATION_ERROR` and field details, while other errors still exclude details.
- Validation/conflict script passed on Windows PowerShell 5.1: 185 cases and 202
  HTTP requests. It covers missing/null/blank fields, lengths, dates and ranges,
  numeric types/ranges, enums, malformed JSON, defaults, valid POST/PUT, duplicates,
  unchanged data/IDs after rejection, self-updates, different owners, administrator
  permissions, CRUD, 401/403/404/405, Allow headers, and bodyless HEAD responses.
- A second validation run passed without restarting and restored all pre-existing
  data, confirming repeatability and cleanup.
- Temporary copies outside the repository used intentionally incorrect assertions.
  Both scripts reported the expected/actual mismatch and exited 1; the validation
  copy also confirmed cleanup after failure. No API bugs were found.

The Stage 3 and Stage 4 reports are historical records. This report describes the
current validation/conflict contract and the updated test commands.
