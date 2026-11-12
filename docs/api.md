# ClubFlow API v1

Local origin: `http://localhost:5024`. API prefix: `/api/v1`.
Start the backend with `dotnet run --project src/ClubFlow.Api` from the repository root.
The greeting page is public; the five Events endpoints require authentication.

## Endpoints and access

| Method | Path | Access | Success |
| --- | --- | --- | --- |
| GET | `/api/v1/events` | Regular: own events; Administrator: all events | 200 JSON |
| GET | `/api/v1/events/{id}` | Owner or Administrator | 200 JSON |
| POST | `/api/v1/events` | Regular or Administrator | 201 JSON + Location |
| PUT | `/api/v1/events/{id}` | Owner or Administrator | 200 JSON |
| DELETE | `/api/v1/events/{id}` | Owner or Administrator | 200 JSON |
| GET | `/api/v1/greeting` | Public; no token needed | 200 HTML |

There are no login or token-generation endpoints. Use one of these predefined tokens:

| Authorization header | User ID | Role |
| --- | --- | --- |
| `Bearer user-a-token` | `user-a` | Regular |
| `Bearer user-b-token` | `user-b` | Regular |
| `Bearer admin-token` | `admin` | Administrator |

For Events, send `Authorization: Bearer <token>`. POST and PUT also need
`Content-Type: application/json`. `Accept: application/json` is useful but optional.
For the greeting, `Accept: text/html` is optional. Responses use UTF-8.
The bearer scheme is case-insensitive; token values are case-sensitive.

## Parameters and event rules

`id` is an integer path parameter. IDs are server-generated. An unknown numeric ID
returns 404; a non-integer path parameter returns 400.

GET `/events` accepts these optional query parameters:

| Parameter | Default | Allowed values |
| --- | --- | --- |
| `page` | 1 | Integer, at least 1 |
| `perPage` | 20 | Integer, 1-100 |

Events are ordered by ascending ID. Ownership filtering happens before pagination.
`meta.total` counts all accessible events before pagination, not just the returned
page. Pages beyond the available data return 200 with an empty `data` array.

POST and PUT use the same request fields:

| Field | JSON type | Validation / default |
| --- | --- | --- |
| `title` | string | Required, nonblank, 3-100 characters |
| `description` | string | Required, nonblank, at most 1000 characters |
| `location` | string | Required, nonblank, at most 150 characters |
| `startTimeUtc` | date/time string | Required valid timestamp; normalized to UTC |
| `endTimeUtc` | date/time string | Required valid timestamp, later than start; normalized to UTC |
| `capacity` | integer | Required, 1-2147483647 |
| `expectedAttendance` | integer | 0-2147483647; defaults to 0 when omitted |
| `status` | string | `Draft`, `Published`, or `Cancelled`; defaults to `Draft` |

Use ISO 8601 timestamps, preferably with `Z` or an explicit offset, as in the
examples below. Past events are allowed. Explicit nulls, numeric strings, fractions
for integer fields, and malformed JSON are rejected. Status input is case-insensitive;
responses use the exact spellings above. Numeric statuses and combinations of names
are rejected. There is no rule requiring expected attendance to be within capacity.

PUT replaces the editable fields. Required fields must be sent again, and omitted
optional fields reset to their defaults. POST sets `ownerId` to the authenticated
user ID, including `admin` for administrator-created events. PUT preserves the
original ID and owner. Unknown JSON properties are ignored, so body-supplied `id`,
`ownerId`, or role fields cannot change identity or permissions.

Within one owner's events, the combination of title, location, and start-time instant
must be unique. Title and location comparisons ignore case and leading/trailing
whitespace. PUT excludes its own ID. Administrators updating another user's event
follow that original owner's duplicate rule. Different owners may use identical
details. Conflict checking and writes are atomic under the store lock; a rejected
duplicate changes no event and consumes no new ID.

## Example requests and success responses

These examples assume a fresh server. Create the workshop first; it receives ID 5
after the four seeded events. Copy the actual returned ID when using an existing
server. The ready-to-use examples are also in [events.http](../requests/events.http).

### POST /api/v1/events

```http
POST http://localhost:5024/api/v1/events
Authorization: Bearer user-a-token
Content-Type: application/json

{
  "title": "API Design Workshop",
  "description": "Learn REST API design with the Programming Club.",
  "location": "Engineering Lab 204",
  "startTimeUtc": "2026-12-12T13:00:00Z",
  "endTimeUtc": "2026-12-12T15:00:00Z",
  "capacity": 30,
  "expectedAttendance": 24,
  "status": "Draft"
}
```

HTTP 201, `Location: http://localhost:5024/api/v1/events/5`:

```json
{
  "success": true,
  "message": "Event created successfully.",
  "data": {
    "id": 5,
    "ownerId": "user-a",
    "title": "API Design Workshop",
    "description": "Learn REST API design with the Programming Club.",
    "location": "Engineering Lab 204",
    "startTimeUtc": "2026-12-12T13:00:00+00:00",
    "endTimeUtc": "2026-12-12T15:00:00+00:00",
    "capacity": 30,
    "expectedAttendance": 24,
    "status": "Draft"
  }
}
```

### GET /api/v1/events

```http
GET http://localhost:5024/api/v1/events?page=2&perPage=2
Authorization: Bearer user-a-token
```

HTTP 200. User A has two seeded events and the new workshop, so this page contains
only ID 5:

```json
{
  "success": true,
  "message": "Events retrieved successfully.",
  "data": [
    {
      "id": 5,
      "ownerId": "user-a",
      "title": "API Design Workshop",
      "description": "Learn REST API design with the Programming Club.",
      "location": "Engineering Lab 204",
      "startTimeUtc": "2026-12-12T13:00:00+00:00",
      "endTimeUtc": "2026-12-12T15:00:00+00:00",
      "capacity": 30,
      "expectedAttendance": 24,
      "status": "Draft"
    }
  ],
  "meta": { "total": 3, "page": 2, "perPage": 2 }
}
```

### GET /api/v1/events/{id}

```http
GET http://localhost:5024/api/v1/events/5
Authorization: Bearer user-a-token
```

HTTP 200 uses `success: true`, message `Event retrieved successfully.`, and `data`
containing the same complete event object shown in the POST response. It has no
`meta` field. A regular user requesting another owner's existing event receives 403.

### PUT /api/v1/events/{id}

```http
PUT http://localhost:5024/api/v1/events/5
Authorization: Bearer user-a-token
Content-Type: application/json

{
  "title": "API Design Workshop - revised",
  "description": "Practice API design and HTTP testing with the Programming Club.",
  "location": "Engineering Lab 205",
  "startTimeUtc": "2026-12-12T13:00:00Z",
  "endTimeUtc": "2026-12-12T15:00:00Z",
  "capacity": 40,
  "expectedAttendance": 32,
  "status": "Published"
}
```

HTTP 200 uses `success: true`, message `Event updated successfully.`, and `data`
containing the complete updated event. `id` stays 5, `ownerId` stays `user-a`, the
other fields match the request, and timestamps use `+00:00`. No `meta` is included.

### DELETE /api/v1/events/{id}

```http
DELETE http://localhost:5024/api/v1/events/5
Authorization: Bearer user-a-token
```

HTTP 200:

```json
{ "success": true, "message": "Event deleted successfully.", "data": null }
```

### GET /api/v1/greeting

```http
GET http://localhost:5024/api/v1/greeting
Accept: text/html
```

HTTP 200, `Content-Type: text/html; charset=utf-8`. This is a responsive HTML page
with the project description, team members and student IDs, six endpoints, API
running status, and version v1. It is not wrapped in a JSON envelope.

## Error responses

| Status | Code | When |
| --- | --- | --- |
| 400 | `VALIDATION_ERROR` | Invalid POST/PUT fields, body, or path parameter |
| 400 | `INVALID_PAGINATION` | Numeric page/perPage outside allowed ranges |
| 400 | `INVALID_REQUEST` | Invalid GET/DELETE parameter types, including non-integer IDs |
| 401 | `UNAUTHORIZED` | Missing, invalid, malformed, or unsupported Events credentials |
| 403 | `FORBIDDEN` | Authenticated regular user accessing another owner's event |
| 404 | `NOT_FOUND` | Numeric event ID does not exist |
| 405 | `METHOD_NOT_ALLOWED` | Method not supported on a defined route |
| 409 | `CONFLICT` | Same-owner duplicate title, location, and start time |

Success envelopes contain `success`, `message`, and `data`; only lists add `meta`.
Error envelopes contain `success: false` and `error`. Only validation errors add
`error.details`. For example, capacity 0 returns HTTP 400:

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

An identical POST by the same owner, or a PUT duplicating another owned event,
returns HTTP 409:

```json
{
  "success": false,
  "error": {
    "code": "CONFLICT",
    "message": "An event with the same title, location and start time already exists."
  }
}
```

Other exact error messages are:

- `UNAUTHORIZED`: `Authentication is required.`
- `FORBIDDEN`: `You do not have permission to access this event.`
- `NOT_FOUND`: `Event not found.`
- `METHOD_NOT_ALLOWED`: `The HTTP method is not allowed for this resource.`
- `INVALID_PAGINATION`: `Page must be at least 1 and perPage must be between 1 and 100.`
- `INVALID_REQUEST`: `The request body or parameters are invalid.`

401 responses include `WWW-Authenticate: Bearer`. A 405 includes the Allow header:
`GET, POST` for the Events collection, `GET, PUT, DELETE` for an event, and `GET`
for the greeting (order may vary). HEAD is not an implemented action: it returns
405 with headers and no body. Unknown routes, including `/`, return a routing 404
that may have an empty body rather than `NOT_FOUND` JSON.

Send JSON for writes: an unsupported body Content-Type returns HTTP 415 using
ASP.NET Core's Problem Details response rather than the application envelope.
Authentication runs before body validation, so a missing token still returns 401.
Body validation happens before controller ownership/existence checks; an invalid
PUT can return 400 before 403 or 404. Internal exception details are not part of
the application's error responses.

## In-memory lifetime

On first use, the singleton store seeds four university events: IDs 1 and 2 belong
to `user-a`; IDs 3 and 4 belong to `user-b`. Seed dates are 7-21 days ahead of
initialization. All changes exist only in the running process. Restarting restores
the four seed events and resets ID allocation. There is no database persistence.
