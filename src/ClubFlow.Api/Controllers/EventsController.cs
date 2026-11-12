using ClubFlow.Api.Dtos;
using ClubFlow.Api.Models;
using ClubFlow.Api.Responses;
using ClubFlow.Api.Services;
using Microsoft.AspNetCore.Mvc;

namespace ClubFlow.Api.Controllers;

[ApiController]
[Route("api/v1/events")]
public sealed class EventsController : ControllerBase
{
    private readonly EventStore _eventStore;

    public EventsController(EventStore eventStore)
    {
        _eventStore = eventStore;
    }

    [HttpGet]
    public IActionResult GetAll([FromQuery] int page = 1, [FromQuery] int perPage = 20)
    {
        if (page < 1 || perPage < 1 || perPage > 100)
        {
            return BadRequest(new ApiErrorResponse(new ApiError(
                "INVALID_PAGINATION", "Page must be at least 1 and perPage must be between 1 and 100.")));
        }

        var events = _eventStore.GetAll();
        var offset = (long)(page - 1) * perPage;
        var data = offset >= events.Count
            ? Array.Empty<Event>()
            : events.Skip((int)offset).Take(perPage).ToArray();

        return Ok(new ApiResponse<Event[]>("Events retrieved successfully.", data)
        {
            Meta = new PaginationMeta(events.Count, page, perPage)
        });
    }

    [HttpGet("{id}")]
    public IActionResult GetById(int id)
    {
        var clubEvent = _eventStore.GetById(id);
        if (clubEvent is null)
        {
            return EventNotFound();
        }

        return Ok(new ApiResponse<Event>("Event retrieved successfully.", clubEvent));
    }

    [HttpPost]
    public IActionResult Create(CreateEventRequest request)
    {
        var createdEvent = _eventStore.Create(new Event
        {
            OwnerId = request.OwnerId,
            Title = request.Title,
            Description = request.Description,
            Location = request.Location,
            StartTimeUtc = request.StartTimeUtc.ToUniversalTime(),
            EndTimeUtc = request.EndTimeUtc.ToUniversalTime(),
            Capacity = request.Capacity,
            ExpectedAttendance = request.ExpectedAttendance,
            Status = request.Status
        });

        return CreatedAtAction(nameof(GetById), new { id = createdEvent.Id },
            new ApiResponse<Event>("Event created successfully.", createdEvent));
    }

    [HttpPut("{id}")]
    public IActionResult Update(int id, UpdateEventRequest request)
    {
        var existingEvent = _eventStore.GetById(id);
        if (existingEvent is null)
        {
            return EventNotFound();
        }

        var updatedEvent = _eventStore.Update(id, existingEvent with
        {
            Title = request.Title,
            Description = request.Description,
            Location = request.Location,
            StartTimeUtc = request.StartTimeUtc.ToUniversalTime(),
            EndTimeUtc = request.EndTimeUtc.ToUniversalTime(),
            Capacity = request.Capacity,
            ExpectedAttendance = request.ExpectedAttendance,
            Status = request.Status
        });

        if (updatedEvent is null)
        {
            return EventNotFound();
        }

        return Ok(new ApiResponse<Event>("Event updated successfully.", updatedEvent));
    }

    [HttpDelete("{id}")]
    public IActionResult Delete(int id)
    {
        if (!_eventStore.Delete(id))
        {
            return EventNotFound();
        }

        return Ok(new ApiResponse<Event?>("Event deleted successfully.", null));
    }

    private NotFoundObjectResult EventNotFound()
    {
        return NotFound(new ApiErrorResponse(new ApiError("NOT_FOUND", "Event not found.")));
    }
}
