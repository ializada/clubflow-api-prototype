# ClubFlow API Prototype

## About

ClubFlow is an event and volunteer management platform for student clubs and small
organizations. This prototype implements the event management REST API using mock
data. It includes event CRUD, predefined bearer tokens, ownership permissions,
request validation, duplicate-event handling, and a public HTML greeting page.

Data is stored in memory. Restarting the backend restores four sample university
events and resets ID allocation.

## Requirements

- .NET 10 SDK
- Windows PowerShell 5.1 or later for the HTTP test scripts
- Git to inspect contribution history

## Getting Started

Run these commands from the repository root:

```powershell
dotnet restore
dotnet build
dotnet run --project src/ClubFlow.Api
```

The development URL is `http://localhost:5024`. Open the public greeting page at
[http://localhost:5024/api/v1/greeting](http://localhost:5024/api/v1/greeting).
Press Ctrl+C to stop the backend. `/` has no route and returns 404.

## API Endpoints

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/api/v1/events` | List accessible events with pagination |
| GET | `/api/v1/events/{id}` | Retrieve an event |
| POST | `/api/v1/events` | Create an event |
| PUT | `/api/v1/events/{id}` | Replace editable event fields |
| DELETE | `/api/v1/events/{id}` | Delete an event |
| GET | `/api/v1/greeting` | Public HTML project and team overview |

See [docs/api.md](docs/api.md) for headers, parameters, payloads, responses, and
error codes. [requests/events.http](requests/events.http) provides example requests
for HTTP clients that support `.http` files.

## Authentication

All Events endpoints require `Authorization: Bearer <token>`. The greeting page
requires no authentication.

| Mock token | User ID | Role |
| --- | --- | --- |
| `user-a-token` | `user-a` | Regular |
| `user-b-token` | `user-b` | Regular |
| `admin-token` | `admin` | Administrator |

Regular users can manage only their own events. Administrators can access all
events. The creator's identity determines ownership; request bodies cannot change
IDs, owners, or roles. These tokens are for the prototype; there is no login flow.

## Event Rules

- Title, description, and location are required and cannot be blank. Title is
  3-100 characters; description allows up to 1000 and location up to 150.
- Start and end times are required; end must be later. Times normalize to UTC,
  and past dates are allowed.
- Capacity is a required positive integer. Expected attendance is nonnegative
  and defaults to 0. Status is Draft, Published, or Cancelled and defaults to Draft.
- An owner cannot have duplicate title, location, and start-time combinations.
  Comparisons ignore title/location case and surrounding whitespace. Other owners
  may use identical details. Conflicting writes return 409 without changing data.

Lists default to page 1 and 20 events per page (maximum 100). Ownership filtering
happens before pagination, and totals count only accessible events. JSON writes
use `Content-Type: application/json`; validation failures return 400 with field details.

## Testing

Run the scripts sequentially against a local development instance. The authentication
script needs a fresh backend with the original four events and initial ID allocation:

```powershell
powershell.exe -NoProfile -File .\scripts\Test-EventAuthentication.ps1 -BaseUrl http://localhost:5024
```

Stop and restart the backend using the run command above, then run:

```powershell
powershell.exe -NoProfile -File .\scripts\Test-EventAuthentication.ps1 -AfterRestart -BaseUrl http://localhost:5024
powershell.exe -NoProfile -File .\scripts\Test-EventValidation.ps1 -BaseUrl http://localhost:5024
```

Both scripts support Windows PowerShell 5.1 and return a nonzero exit code on
failure. The validation script uses unique data and cleans up its own events, so
it can be rerun without restarting. Existing [verification reports](docs/) record
the HTTP coverage. The greeting can be checked directly in a browser.

## Project Structure

```text
ClubFlow.sln
src/ClubFlow.Api/
  Authentication/    Mock bearer-token handler
  Controllers/       Events and greeting endpoints
  Dtos/              Create/update requests and validation
  Models/            Event and EventStatus
  Responses/         JSON envelopes and validation errors
  Serialization/     Status JSON conversion
  Services/          In-memory EventStore
  Properties/        Development launch settings
  Program.cs         Startup and middleware
scripts/             Authentication and validation HTTP tests
docs/                API reference and verification reports
requests/            Example HTTP requests
CONTRIBUTORS.md       Team details
```

## Contributors

- **Ismayil Alizada (18162):** backend setup, Event model, mock data and CRUD endpoints.
- **Toghrul Ismayilzada (18124):** mock authentication, authorization, request validation and error handling.
- **Zamin Ashurov (18125):** greeting page, API documentation, testing and final project documentation.

GitHub usernames and responsibilities are listed in [CONTRIBUTORS.md](CONTRIBUTORS.md).
Contribution snapshot taken during final preparation (2026-11-12):

```text
    14  Ismayil Alizada
     6  Toghrul Ismayilzada
     4  Zamin Ashurov
```

Counts change as commits and pull requests are merged. Generate the latest output with:

```powershell
git shortlog -sn --all
```
