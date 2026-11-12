using ClubFlow.Api.Services;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();
builder.Services.AddSingleton<EventStore>();

var app = builder.Build();

app.MapControllers();

app.Run();
