# Stage 3 HTTP verification

Verified locally on 2026-11-12 against `http://localhost:5024` using actual HTTP
requests. `dotnet restore` and `dotnet build` passed with zero warnings and errors.
The server was started with:

```powershell
dotnet run --project src/ClubFlow.Api --no-build --no-restore
```

All request paths below are relative to that base URL. All POST and PUT requests
used `Content-Type: application/json`. Requests without a listed body had no body.

Create body **C** (the extra `id` deliberately tests that clients cannot assign IDs):

```json
{
  "id": 999,
  "ownerId": "user-a",
  "title": "Student API Workshop",
  "description": "Build and test an API with the Programming Club.",
  "location": "Engineering Lab 204",
  "startTimeUtc": "2026-12-05T13:00:00Z",
  "endTimeUtc": "2026-12-05T15:00:00Z",
  "capacity": 30,
  "expectedAttendance": 24,
  "status": "Draft"
}
```

Update body **U** (the extra `id` and `ownerId` deliberately test identity preservation):

```json
{
  "id": 777,
  "ownerId": "user-b",
  "title": "Advanced API Workshop",
  "description": "Test HTTP endpoints with the Programming Club.",
  "location": "Engineering Lab 205",
  "startTimeUtc": "2026-12-06T17:00:00+04:00",
  "endTimeUtc": "2026-12-06T19:00:00+04:00",
  "capacity": 40,
  "expectedAttendance": 32,
  "status": "Cancelled"
}
```

Requests and observed status codes, in execution order:

| # | Method | Path | Body | Status |
| --- | --- | --- | --- | --- |
| 1 | GET | `/api/v1/events` | — | 200 |
| 2 | GET | `/api/v1/events?page=2&perPage=2` | — | 200 |
| 3 | GET | `/api/v1/events?page=2147483647&perPage=100` | — | 200 |
| 4 | GET | `/api/v1/events/1` | — | 200 |
| 5 | GET | `/api/v1/events/999999` | — | 404 |
| 6 | POST | `/api/v1/events` | C | 201 |
| 7 | GET | `/api/v1/events/5` | — | 200 |
| 8 | GET | `/api/v1/events` | — | 200 |
| 9 | PUT | `/api/v1/events/5` | U | 200 |
| 10 | GET | `/api/v1/events/5` | — | 200 |
| 11 | PUT | `/api/v1/events/999999` | U | 404 |
| 12 | DELETE | `/api/v1/events/999999` | — | 404 |
| 13 | DELETE | `/api/v1/events/5` | — | 200 |
| 14 | GET | `/api/v1/events/5` | — | 404 |
| 15 | GET | `/api/v1/events` | — | 200 |
| 16 | GET | `/api/v1/events?page=0` | — | 400 |
| 17 | GET | `/api/v1/events?perPage=0` | — | 400 |
| 18 | GET | `/api/v1/events?perPage=101` | — | 400 |
| 19 | GET | `/api/v1/events?page=abc` | — | 400 |
| 20 | GET | `/api/v1/events/abc` | — | 400 |
| 21 | POST | `/api/v1/events` | Literal `{` | 400 |
| 22 | POST | `/api/v1/events` | C with `"status":"Unknown"` | 400 |
| 23 | POST | `/api/v1/events` | C with `"status":1` | 400 |
| 24 | POST | `/api/v1/events` | Literal `null` | 400 |
| 25 | PUT | `/api/v1/events/1` | U | 200 |
| 26 | DELETE | `/api/v1/events/2` | — | 200 |
| 27 | POST | `/api/v1/events` | C | 201 |
| 28 | GET | `/api/v1/events` | — | 200 |

The server was stopped with Ctrl+C and restarted with the same command before
the following requests:

| # | Method | Path | Body | Status |
| --- | --- | --- | --- | --- |
| 29 | GET | `/api/v1/events` | — | 200 |
| 30 | GET | `/api/v1/events/5` | — | 404 |
| 31 | GET | `/api/v1/events/6` | — | 404 |
| 32 | POST | `/api/v1/events` | C | 201 |
| 33 | DELETE | `/api/v1/events/5` | — | 200 |

All assertions passed:

- JSON content type and the required success/error envelope were checked for
  requests 1–28. DELETE returned `success: true` and an explicit `data: null`.
- Default pagination was page 1, perPage 20, total 4. Page 2 with perPage 2 returned
  IDs 3 and 4. A very large page returned an empty list without overflow.
- POST allocated ID 5 and returned
  `Location: http://localhost:5024/api/v1/events/5`; the event appeared in GET and
  list results, increasing total to 5. The supplied ID 999 was ignored.
- PUT persisted every editable field, normalized the supplied offsets to UTC,
  and preserved ID 5 and owner `user-a` despite the supplied identity properties.
- Deleting ID 5 removed it. The remaining four events matched the original data
  exactly, confirming that other events were unaffected.
- Missing GET, PUT, and DELETE targets returned `NOT_FOUND`. Pagination errors
  returned `INVALID_PAGINATION`; malformed parameters, JSON, and enums returned
  `INVALID_REQUEST`.
- Before restart, ID 1 was modified, ID 2 was deleted, and a new event had ID 6.
  Restart restored all four original events exactly; IDs 5 and 6 returned 404.
  The next POST allocated ID 5 again, confirming that ID allocation also reset.

The server was stopped after verification. No authentication or detailed field
validation was added. Body-supplied ownership remains temporary for this stage.
