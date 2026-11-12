using System.Text.Json.Serialization;

namespace ClubFlow.Api.Responses;

public sealed record ApiResponse<T>(string Message, T Data)
{
    public bool Success => true;

    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public PaginationMeta? Meta { get; init; }
}

public sealed record PaginationMeta(int Total, int Page, int PerPage);

public sealed record ApiErrorResponse(ApiError Error)
{
    public bool Success => false;
}

public sealed record ApiError(
    string Code,
    string Message,
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    IReadOnlyList<ValidationErrorDetail>? Details = null);

public sealed record ValidationErrorDetail(string Field, string Message);
