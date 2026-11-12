using System.ComponentModel.DataAnnotations;
using ClubFlow.Api.Models;

namespace ClubFlow.Api.Dtos;

public sealed record UpdateEventRequest : IValidatableObject
{
    [Required(ErrorMessage = "Title is required and cannot be blank.")]
    [StringLength(100, MinimumLength = 3, ErrorMessage = "Title must contain between 3 and 100 characters.")]
    public string Title { get; init; } = string.Empty;

    [Required(ErrorMessage = "Description is required and cannot be blank.")]
    [StringLength(1000, ErrorMessage = "Description must contain no more than 1000 characters.")]
    public string Description { get; init; } = string.Empty;

    [Required(ErrorMessage = "Location is required and cannot be blank.")]
    [StringLength(150, ErrorMessage = "Location must contain no more than 150 characters.")]
    public string Location { get; init; } = string.Empty;

    [Required(ErrorMessage = "Start time is required.")]
    public DateTimeOffset? StartTimeUtc { get; init; }

    [Required(ErrorMessage = "End time is required.")]
    public DateTimeOffset? EndTimeUtc { get; init; }

    [Required(ErrorMessage = "Capacity is required.")]
    [Range(1, int.MaxValue, ErrorMessage = "Capacity must be a positive integer.")]
    public int? Capacity { get; init; }

    [Range(0, int.MaxValue, ErrorMessage = "Expected attendance must be a nonnegative integer.")]
    public int ExpectedAttendance { get; init; }

    [EnumDataType(typeof(EventStatus), ErrorMessage = "Status must be Draft, Published, or Cancelled.")]
    public EventStatus Status { get; init; }

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        if (StartTimeUtc is { } start && EndTimeUtc is { } end && end <= start)
        {
            yield return new ValidationResult("End time must be later than start time.",
                new[] { nameof(EndTimeUtc) });
        }
    }
}
