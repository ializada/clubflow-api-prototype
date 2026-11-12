namespace ClubFlow.Api.Models;

public sealed record Event
{
    public int Id { get; init; }
    public string OwnerId { get; init; } = string.Empty;
    public string Title { get; init; } = string.Empty;
    public string Description { get; init; } = string.Empty;
    public string Location { get; init; } = string.Empty;
    public DateTimeOffset StartTimeUtc { get; init; }
    public DateTimeOffset EndTimeUtc { get; init; }
    public int Capacity { get; init; }
    public int ExpectedAttendance { get; init; }
    public EventStatus Status { get; init; }
}
