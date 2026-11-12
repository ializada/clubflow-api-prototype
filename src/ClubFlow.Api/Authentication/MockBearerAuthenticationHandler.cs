using System.Net.Http.Headers;
using System.Security.Claims;
using System.Text.Encodings.Web;
using ClubFlow.Api.Responses;
using Microsoft.AspNetCore.Authentication;
using Microsoft.Extensions.Options;

namespace ClubFlow.Api.Authentication;

public sealed class MockBearerAuthenticationHandler : AuthenticationHandler<AuthenticationSchemeOptions>
{
    public const string SchemeName = "MockBearer";
    public const string AdministratorRole = "Administrator";

    private static readonly Dictionary<string, (string UserId, string Role)> Users = new(StringComparer.Ordinal)
    {
        ["user-a-token"] = ("user-a", "Regular"),
        ["user-b-token"] = ("user-b", "Regular"),
        ["admin-token"] = ("admin", AdministratorRole)
    };

    public MockBearerAuthenticationHandler(
        IOptionsMonitor<AuthenticationSchemeOptions> options,
        ILoggerFactory logger,
        UrlEncoder encoder) : base(options, logger, encoder)
    {
    }

    protected override Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        var authorization = Request.Headers.Authorization;
        if (authorization.Count == 0)
        {
            return Task.FromResult(AuthenticateResult.NoResult());
        }

        if (authorization.Count != 1
            || !AuthenticationHeaderValue.TryParse(authorization[0], out var header)
            || !string.Equals(header.Scheme, "Bearer", StringComparison.OrdinalIgnoreCase)
            || !Users.TryGetValue(header.Parameter ?? string.Empty, out var user))
        {
            return Task.FromResult(AuthenticateResult.Fail("Invalid bearer credentials."));
        }

        var claims = new[]
        {
            new Claim(ClaimTypes.NameIdentifier, user.UserId),
            new Claim(ClaimTypes.Role, user.Role)
        };
        var principal = new ClaimsPrincipal(new ClaimsIdentity(claims, Scheme.Name));
        var ticket = new AuthenticationTicket(principal, Scheme.Name);

        return Task.FromResult(AuthenticateResult.Success(ticket));
    }

    protected override Task HandleChallengeAsync(AuthenticationProperties properties)
    {
        Response.Headers.WWWAuthenticate = "Bearer";
        return WriteErrorAsync(StatusCodes.Status401Unauthorized,
            "UNAUTHORIZED", "Authentication is required.");
    }

    protected override Task HandleForbiddenAsync(AuthenticationProperties properties)
    {
        return WriteErrorAsync(StatusCodes.Status403Forbidden,
            "FORBIDDEN", "You do not have permission to access this event.");
    }

    private Task WriteErrorAsync(int statusCode, string code, string message)
    {
        Response.StatusCode = statusCode;
        return Response.WriteAsJsonAsync(new ApiErrorResponse(new ApiError(code, message)),
            Context.RequestAborted);
    }
}
