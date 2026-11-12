# clubflow-api-prototype

ClubFlow is an event and volunteer management platform for student clubs.
This initial setup contains an ASP.NET Core Web API targeting .NET 10 with controller support.

## Local setup

Install the .NET 10 SDK, then run these commands from the repository root:

```powershell
dotnet restore
dotnet build
dotnet run --project src/ClubFlow.Api
```

The API starts at `http://localhost:5024` using the HTTP development launch profile.
Press `Ctrl+C` to stop it.

No endpoints are implemented yet, so requests to `/` return HTTP 404.
Controllers for later assignment stages will go in `src/ClubFlow.Api/Controllers/`.

## Project structure

```text
ClubFlow.sln
src/
  ClubFlow.Api/
    Controllers/
    Properties/launchSettings.json
    appsettings.json
    appsettings.Development.json
    ClubFlow.Api.csproj
    Program.cs
```
