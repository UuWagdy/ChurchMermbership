using System.Text.Json;
using System.Text.Json.Serialization;

namespace AbonaFlemoon.SyncServer.Models;

public class SqlParamDto
{
    [JsonPropertyName("type")]
    public string Type { get; set; } = "null";

    [JsonPropertyName("value")]
    public JsonElement? Value { get; set; }
}

public class SqlStatementRequest
{
    [JsonPropertyName("sql")]
    public string Sql { get; set; } = string.Empty;

    [JsonPropertyName("params")]
    public List<SqlParamDto> Params { get; set; } = new();

    [JsonPropertyName("txId")]
    public string? TxId { get; set; }
}

public class SqlBatchStatementDto
{
    [JsonPropertyName("sql")]
    public string Sql { get; set; } = string.Empty;

    [JsonPropertyName("params")]
    public List<SqlParamDto> Params { get; set; } = new();
}

public class SqlBatchRequest
{
    [JsonPropertyName("statements")]
    public List<SqlBatchStatementDto> Statements { get; set; } = new();

    [JsonPropertyName("txId")]
    public string? TxId { get; set; }
}

public class TxActionRequest
{
    [JsonPropertyName("txId")]
    public string TxId { get; set; } = string.Empty;
}

public class QueryResultResponse
{
    [JsonPropertyName("rows")]
    public List<Dictionary<string, object?>> Rows { get; set; } = new();
}

public class ExecuteResultResponse
{
    [JsonPropertyName("affectedRows")]
    public int AffectedRows { get; set; }
}

public class InsertResultResponse
{
    [JsonPropertyName("lastInsertRowId")]
    public long LastInsertRowId { get; set; }
}

public class TxBeginResponse
{
    [JsonPropertyName("txId")]
    public string TxId { get; set; } = string.Empty;
}

public class DatabaseChangeNotification
{
    [JsonPropertyName("tables")]
    public List<string> Tables { get; set; } = new();

    [JsonPropertyName("operation")]
    public string Operation { get; set; } = "write";

    [JsonPropertyName("timestampUtc")]
    public DateTime TimestampUtc { get; set; } = DateTime.UtcNow;
}
