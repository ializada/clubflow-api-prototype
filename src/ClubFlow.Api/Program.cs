using System.Text.Json.Serialization;
using ClubFlow.Api.Authentication;
using ClubFlow.Api.Responses;
using ClubFlow.Api.Serialization;
using ClubFlow.Api.Services;
using Microsoft.AspNetCore.Authentication;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers()
    .AddJsonOptions(options =>
    {
        options.JsonSerializerOptions.NumberHandling = JsonNumberHandling.Strict;
        options.JsonSerializerOptions.Converters.Add(new EventStatusJsonConverter());
    })
    .ConfigureApiBehaviorOptions(options =>
    {
        options.InvalidModelStateResponseFactory = ValidationErrorResponseFactory.Create;
    });
builder.Services.AddSingleton<EventStore>();
builder.Services.AddAuthentication(MockBearerAuthenticationHandler.SchemeName)
    .AddScheme<AuthenticationSchemeOptions, MockBearerAuthenticationHandler>(
        MockBearerAuthenticationHandler.SchemeName, _ => { });
builder.Services.AddAuthorization();

var app = builder.Build();

app.UseStatusCodePages(async context =>
{
    if (context.HttpContext.Response.StatusCode == StatusCodes.Status405MethodNotAllowed)
    {
        await context.HttpContext.Response.WriteAsJsonAsync(new ApiErrorResponse(new ApiError(
            "METHOD_NOT_ALLOWED", "The HTTP method is not allowed for this resource.")),
            context.HttpContext.RequestAborted);
    }
});

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

app.Run();
