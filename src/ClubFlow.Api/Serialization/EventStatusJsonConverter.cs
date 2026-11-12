using System.Text.Json;
using System.Text.Json.Serialization;
using ClubFlow.Api.Models;

namespace ClubFlow.Api.Serialization;

public sealed class EventStatusJsonConverter : JsonConverter<EventStatus>
{
    public override EventStatus Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
    {
        if (reader.TokenType == JsonTokenType.String)
        {
            var text = reader.GetString();
            if (Enum.TryParse<EventStatus>(text, ignoreCase: true, out var status)
                && Enum.IsDefined(status)
                && string.Equals(text, status.ToString(), StringComparison.OrdinalIgnoreCase))
            {
                return status;
            }
        }

        throw new JsonException("Status must be Draft, Published, or Cancelled.");
    }

    public override void Write(Utf8JsonWriter writer, EventStatus value, JsonSerializerOptions options)
    {
        writer.WriteStringValue(value.ToString());
    }
}
