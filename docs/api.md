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

HTTP 200, with no `meta` field:

```json
{
  "success": true,
  "message": "Event retrieved successfully.",
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

A regular user requesting another owner's existing event receives 403.

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

HTTP 200. The ID and owner are preserved; timestamps are normalized to UTC:

```json
{
  "success": true,
  "message": "Event updated successfully.",
  "data": {
    "id": 5,
    "ownerId": "user-a",
    "title": "API Design Workshop - revised",
    "description": "Practice API design and HTTP testing with the Programming Club.",
    "location": "Engineering Lab 205",
    "startTimeUtc": "2026-12-12T13:00:00+00:00",
    "endTimeUtc": "2026-12-12T15:00:00+00:00",
    "capacity": 40,
    "expectedAttendance": 32,
    "status": "Published"
  }
}
```

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

No path, query, or body parameters are required. The full response is folded below
because its body includes the page's inline CSS. It is HTML, not a JSON envelope.

<details>
<summary>Complete example response: HTTP 200 and HTML body</summary>

```http
HTTP/1.1 200 OK
Content-Type: text/html; charset=utf-8

<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="description" content="ClubFlow student club event management API prototype.">
  <title>ClubFlow | API v1</title>
  <style>
    :root { color-scheme: light; font-family: system-ui, -apple-system, "Segoe UI", sans-serif; color: #172b2a; background: #f3f5f1; }
    * { box-sizing: border-box; }
    body { margin: 0; line-height: 1.65; }
    main { width: min(1080px, 100%); margin: auto; padding: 36px 24px; }
    header, .brand, .status { display: flex; align-items: center; gap: 12px; }
    header { justify-content: space-between; flex-wrap: wrap; margin-bottom: 40px; }
    .brand { font-weight: 700; letter-spacing: -.02em; }
    .mark { display: grid; place-items: center; width: 42px; height: 42px; border-radius: 12px; color: white; background: #245c4d; font-size: 15px; }
    .status { flex-wrap: wrap; gap: 8px; font-size: 13px; color: #245c4d; }
    .pill { border: 1px solid #c3d5c8; background: #e9f1e9; padding: 5px 12px; border-radius: 24px; }
    .dot { display: inline-block; width: 7px; height: 7px; margin-right: 6px; background: #28774e; border-radius: 50%; }
    .hero { padding: 40px; border: 1px solid #d7dfd7; border-radius: 20px; background: white; }
    .eyebrow { margin: 0 0 12px; font-size: 12px; font-weight: 700; color: #46645b; letter-spacing: .12em; text-transform: uppercase; }
    h1 { margin: 0 0 14px; font-size: clamp(40px, 7vw, 68px); line-height: 1.12; letter-spacing: -.05em; }
    .lead { max-width: 760px; margin: 0; color: #465c55; font-size: 18px; }
    section { margin-top: 40px; }
    h2 { margin: 0; font-size: 24px; letter-spacing: -.025em; }
    .intro { margin: 6px 0 18px; color: #52665f; }
    .endpoints { list-style: none; margin: 0; padding: 0; border: 1px solid #d7dfd7; border-radius: 16px; background: white; overflow: hidden; }
    .endpoint { display: grid; grid-template-columns: 76px minmax(0, 1fr) auto; gap: 16px; align-items: center; padding: 15px 20px; }
    .endpoint + .endpoint { border-top: 1px solid #e6ebe5; }
    code { font-family: Consolas, "SFMono-Regular", monospace; font-size: 14px; overflow-wrap: anywhere; }
    .method { font-size: 11px; font-weight: 800; letter-spacing: .04em; text-align: center; padding: 4px 8px; border-radius: 6px; background: #e8f0eb; color: #245c4d; }
    .write { background: #edf0f7; color: #3f527d; }
    .delete { background: #f8eeea; color: #854e3b; }
    .access { color: #52665f; font-size: 12px; }
    .endpoint-description { margin: 2px 0 0; color: #52665f; font-size: 13px; }
    .team { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 16px; }
    article { padding: 24px; border: 1px solid #d7dfd7; border-radius: 16px; background: white; }
    article h3 { margin: 0 0 3px; font-size: 17px; }
    .student-id { margin: 0 0 14px; font-size: 13px; color: #52665f; }
    article p:last-child { margin: 0; font-size: 14px; color: #465c55; }
    footer { display: flex; justify-content: space-between; flex-wrap: wrap; gap: 8px; margin-top: 32px; padding-top: 20px; border-top: 1px solid #d7dfd7; color: #52665f; font-size: 12px; }
    @media (max-width: 720px) {
      main { padding: 24px 16px; }
      header { margin-bottom: 24px; }
      .hero { padding: 28px 24px; }
      .lead { font-size: 16px; }
      section { margin-top: 30px; }
      .team { grid-template-columns: 1fr; }
      .endpoint { grid-template-columns: 62px minmax(0, 1fr); gap: 10px; padding: 14px 16px; }
      .access { grid-column: 2; }
    }
  </style>
</head>
<body>
  <main>
    <header>
      <div class="brand"><span class="mark" aria-hidden="true">CF</span> ClubFlow API</div>
      <div class="status"><span class="pill"><span class="dot" aria-hidden="true"></span>API is running</span><span class="pill">v1</span></div>
    </header>
    <div class="hero">
      <p class="eyebrow">Student club event management</p>
      <h1>ClubFlow</h1>
      <p class="lead">ClubFlow is an event and volunteer management platform for student clubs and small organizations. This prototype implements the event management REST API using mock data.</p>
    </div>
    <section aria-labelledby="endpoints-title">
      <h2 id="endpoints-title">API endpoints</h2>
      <p class="intro">Events require a bearer token. This greeting page is public.</p>
      <ul class="endpoints">
        <li class="endpoint"><span class="method">GET</span><div><code>/api/v1/events</code><p class="endpoint-description">List events accessible to the current user.</p></div><span class="access">Authenticated</span></li>
        <li class="endpoint"><span class="method">GET</span><div><code>/api/v1/events/{id}</code><p class="endpoint-description">View the details of a specific event.</p></div><span class="access">Authenticated</span></li>
        <li class="endpoint"><span class="method write">POST</span><div><code>/api/v1/events</code><p class="endpoint-description">Create a new event.</p></div><span class="access">Authenticated</span></li>
        <li class="endpoint"><span class="method write">PUT</span><div><code>/api/v1/events/{id}</code><p class="endpoint-description">Update an existing event.</p></div><span class="access">Authenticated</span></li>
        <li class="endpoint"><span class="method delete">DELETE</span><div><code>/api/v1/events/{id}</code><p class="endpoint-description">Delete an event.</p></div><span class="access">Authenticated</span></li>
        <li class="endpoint"><span class="method">GET</span><div><code>/api/v1/greeting</code><p class="endpoint-description">Display ClubFlow project information.</p></div><span class="access">Public</span></li>
      </ul>
    </section>
    <section aria-labelledby="team-title">
      <h2 id="team-title">Meet the team</h2>
      <p class="intro">Three contributors, one ClubFlow prototype.</p>
      <div class="team">
        <article>
          <h3>Ismayil Alizada</h3><p class="student-id">Student ID 18162</p>
          <p>Backend setup, Event model, mock data and CRUD endpoints.</p>
        </article>
        <article>
          <h3>Toghrul Ismayilzada</h3><p class="student-id">Student ID 18124</p>
          <p>Mock authentication, authorization, request validation and error handling.</p>
        </article>
        <article>
          <h3>Zamin Ashurov</h3><p class="student-id">Student ID 18125</p>
          <p>Greeting page, API documentation, testing and final project documentation.</p>
        </article>
      </div>
    </section>
    <footer><span>ClubFlow / API v1</span><span>University software engineering project</span></footer>
  </main>
</body>
</html>
```

</details>

## Error responses

Possible errors by endpoint are listed below. POST and PUT use the shared body
validation rules above; the other endpoints have no request body. The Events
resource routes take integer `id`; only the list endpoint uses `page`/`perPage`.

| Endpoint | Possible HTTP errors |
| --- | --- |
| GET `/api/v1/events` | 400, 401, 405 |
| GET `/api/v1/events/{id}` | 400, 401, 403, 404, 405 |
| POST `/api/v1/events` | 400, 401, 405, 409, 415 |
| PUT `/api/v1/events/{id}` | 400, 401, 403, 404, 405, 409, 415 |
| DELETE `/api/v1/events/{id}` | 400, 401, 403, 404, 405 |
| GET `/api/v1/greeting` | 405 for unsupported methods |

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
