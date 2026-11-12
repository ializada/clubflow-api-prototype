using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace ClubFlow.Api.Controllers;

[ApiController]
[AllowAnonymous]
[Route("api/v1/greeting")]
public sealed class GreetingController : ControllerBase
{
    [HttpGet]
    public ContentResult Get()
    {
        return Content("""
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
            """, "text/html; charset=utf-8");
    }
}
