using System.Text.Json.Serialization;
using ClubFlow.Api.Authentication;
using ClubFlow.Api.Models;
using ClubFlow.Api.Responses;
using ClubFlow.Api.Services;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Mvc;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers()
    .AddJsonOptions(options =>
    {
        options.JsonSerializerOptions.Converters.Add(
            new JsonStringEnumConverter<EventStatus>(allowIntegerValues: false));
    })
    .ConfigureApiBehaviorOptions(options =>
    {
        options.InvalidModelStateResponseFactory = _ => new BadRequestObjectResult(
            new ApiErrorResponse(new ApiError("INVALID_REQUEST", "The request body or parameters are invalid.")));
    });
builder.Services.AddSingleton<EventStore>();
builder.Services.AddAuthentication(MockBearerAuthenticationHandler.SchemeName)
    .AddScheme<AuthenticationSchemeOptions, MockBearerAuthenticationHandler>(
        MockBearerAuthenticationHandler.SchemeName, _ => { });
builder.Services.AddAuthorization();

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

app.Run();
