using System.Text.Json;
using Microsoft.AspNetCore.Mvc;

namespace ClubFlow.Api.Responses;

public static class ValidationErrorResponseFactory
{
    public static IActionResult Create(ActionContext context)
    {
        var request = context.HttpContext.Request;
        if (!HttpMethods.IsPost(request.Method) && !HttpMethods.IsPut(request.Method))
        {
            return new BadRequestObjectResult(new ApiErrorResponse(
                new ApiError("INVALID_REQUEST", "The request body or parameters are invalid.")));
        }

        var hasJsonError = context.ModelState.Keys.Any(key => key.StartsWith('$'));
        var details = context.ModelState
            // A failed JSON parse also produces a redundant missing request-parameter error.
            .Where(entry => !hasJsonError || !context.ActionDescriptor.Parameters.Any(p => p.Name == entry.Key))
            .SelectMany(entry => entry.Value!.Errors.Select(error =>
            {
                var field = entry.Key.StartsWith("$.") ? entry.Key[2..] : entry.Key;
                field = field.ToLowerInvariant() switch
                {
                    "" or "$" or "request" => "body",
                    "starttimeutc" => "startTimeUtc",
                    "endtimeutc" => "endTimeUtc",
                    "expectedattendance" => "expectedAttendance",
                    "title" or "description" or "location" or "capacity" or "status" => field.ToLowerInvariant(),
                    _ => JsonNamingPolicy.CamelCase.ConvertName(field)
                };

                // Never return JSON parser exception messages or CLR type names to clients.
                var message = entry.Key.StartsWith('$') || error.Exception is not null || field == "body"
                    ? InvalidValueMessage(field)
                    : error.ErrorMessage;
                return new ValidationErrorDetail(field, message);
            }))
            .ToArray();

        return new BadRequestObjectResult(new ApiErrorResponse(new ApiError(
            "VALIDATION_ERROR", "The request contains invalid or missing fields.", details)));
    }

    private static string InvalidValueMessage(string field)
    {
        return field switch
        {
            "title" or "description" or "location" => "A string value is required.",
            "startTimeUtc" or "endTimeUtc" => "A valid date/time value is required.",
            "capacity" => "Capacity must be a positive integer.",
            "expectedAttendance" => "Expected attendance must be a nonnegative integer.",
            "status" => "Status must be Draft, Published, or Cancelled.",
            _ => "A valid JSON request body with the expected field types is required."
        };
    }
}
