using ClubFlow.Api.Models;

namespace ClubFlow.Api.Services;

public sealed class EventStore
{
    private readonly object _lock = new();
    private readonly Dictionary<int, Event> _events = new();
    private int _nextId = 1;

    public EventStore()
    {
        var todayUtc = new DateTimeOffset(DateTime.UtcNow.Date, TimeSpan.Zero);

        Create(new Event
        {
            OwnerId = "user-a",
            Title = "Introduction to C# Workshop",
            Description = "Build a small console application with mentors from the Programming Club.",
            Location = "Engineering Building, Computer Lab 204",
            StartTimeUtc = todayUtc.AddDays(7).AddHours(13),
            EndTimeUtc = todayUtc.AddDays(7).AddHours(15),
            Capacity = 30,
            ExpectedAttendance = 24,
            Status = EventStatus.Published
        });

        Create(new Event
        {
            OwnerId = "user-a",
            Title = "Student Hackathon Planning Meetup",
            Description = "Help the Programming Club choose challenges and plan volunteer roles for its next hackathon.",
            Location = "Student Union, Meeting Room 3",
            StartTimeUtc = todayUtc.AddDays(10).AddHours(14),
            EndTimeUtc = todayUtc.AddDays(10).AddHours(15),
            Capacity = 20,
            ExpectedAttendance = 15,
            Status = EventStatus.Draft
        });

        Create(new Event
        {
            OwnerId = "user-b",
            Title = "Graduate Careers and Networking Evening",
            Description = "Meet alumni and local employers to discuss internships, graduate roles, and interview preparation.",
            Location = "Main Campus, Conference Hall",
            StartTimeUtc = todayUtc.AddDays(14).AddHours(13),
            EndTimeUtc = todayUtc.AddDays(14).AddHours(16),
            Capacity = 100,
            ExpectedAttendance = 80,
            Status = EventStatus.Published
        });

        Create(new Event
        {
            OwnerId = "user-b",
            Title = "Interclub Five-a-Side Football Tournament",
            Description = "A friendly tournament for student club teams, with student volunteers supporting match operations.",
            Location = "University Sports Centre, Outdoor Pitch",
            StartTimeUtc = todayUtc.AddDays(21).AddHours(9),
            EndTimeUtc = todayUtc.AddDays(21).AddHours(13),
            Capacity = 60,
            ExpectedAttendance = 50,
            Status = EventStatus.Published
        });
    }

    public IReadOnlyList<Event> GetAll()
    {
        lock (_lock)
        {
            return _events.Values.OrderBy(clubEvent => clubEvent.Id).ToArray();
        }
    }

    public Event? GetById(int id)
    {
        lock (_lock)
        {
            return _events.GetValueOrDefault(id);
        }
    }

    public Event Create(Event clubEvent)
    {
        lock (_lock)
        {
            var createdEvent = clubEvent with { Id = _nextId++ };
            _events.Add(createdEvent.Id, createdEvent);
            return createdEvent;
        }
    }

    public Event? Update(int id, Event clubEvent)
    {
        lock (_lock)
        {
            if (!_events.ContainsKey(id))
            {
                return null;
            }

            var updatedEvent = clubEvent with { Id = id };
            _events[id] = updatedEvent;
            return updatedEvent;
        }
    }

    public bool Delete(int id)
    {
        lock (_lock)
        {
            return _events.Remove(id);
        }
    }
}
