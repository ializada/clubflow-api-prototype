using ClubFlow.Api.Models;

namespace ClubFlow.Api.Dtos;

public sealed record CreateEventRequest
{
    public string Title { get; init; } = string.Empty;
    public string Description { get; init; } = string.Empty;
    public string Location { get; init; } = string.Empty;
    public DateTimeOffset StartTimeUtc { get; init; }
    public DateTimeOffset EndTimeUtc { get; init; }
    public int Capacity { get; init; }
    public int ExpectedAttendance { get; init; }
    public EventStatus Status { get; init; }
}
