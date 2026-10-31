using System.Collections.Concurrent;
using System.Data;
using System.Text.Json;
using AbonaFlemoon.SyncServer.Hubs;
using AbonaFlemoon.SyncServer.Models;
using Microsoft.AspNetCore.SignalR;
using Microsoft.Data.Sqlite;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace AbonaFlemoon.SyncServer.Services;

public sealed class ActiveTransactionContext : IAsyncDisposable
{
    public string TxId { get; init; } = string.Empty;
    public NpgsqlConnection Connection { get; init; } = default!;
    public NpgsqlTransaction Transaction { get; init; } = default!;
    public SemaphoreSlim Gate { get; } = new(1, 1);
    public HashSet<string> TouchedTables { get; } = new(StringComparer.OrdinalIgnoreCase);
    public DateTime LastActivityUtc { get; set; } = DateTime.UtcNow;

    public async ValueTask DisposeAsync()
    {
        Gate.Dispose();
        await Transaction.DisposeAsync();
        await Connection.DisposeAsync();
    }
}

public class StorageService : IDisposable
{
    private readonly string _connectionString;
    private readonly IHubContext<SyncHub> _hubContext;
    private readonly ILogger<StorageService> _logger;
    private readonly ConcurrentDictionary<string, ActiveTransactionContext> _transactions = new();
    private readonly Timer _cleanupTimer;

    public StorageService(
        IConfiguration configuration,
        IHubContext<SyncHub> hubContext,
        ILogger<StorageService> logger)
    {
        _connectionString = configuration.GetConnectionString("Postgres")
            ?? throw new InvalidOperationException("Missing ConnectionStrings:Postgres");
        _hubContext = hubContext;
        _logger = logger;
        _cleanupTimer = new Timer(CleanupStaleTransactions, null, TimeSpan.FromSeconds(30), TimeSpan.FromSeconds(30));
    }

    public async Task<bool> CheckDatabaseHealthAsync()
    {
        try
        {
            await using var conn = new NpgsqlConnection(_connectionString);
            await conn.OpenAsync();
            await using var cmd = new NpgsqlCommand("SELECT 1;", conn);
            await cmd.ExecuteScalarAsync();
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "PostgreSQL health check failed.");
            return false;
        }
    }

    public async Task<TxBeginResponse> BeginTransactionAsync()
    {
        var conn = new NpgsqlConnection(_connectionString);
        await conn.OpenAsync();
        var tx = await conn.BeginTransactionAsync(IsolationLevel.ReadCommitted);
        var txId = Guid.NewGuid().ToString("N");

        var ctx = new ActiveTransactionContext
        {
            TxId = txId,
            Connection = conn,
            Transaction = tx,
            LastActivityUtc = DateTime.UtcNow
        };

        _transactions[txId] = ctx;
        return new TxBeginResponse { TxId = txId };
    }

    public async Task CommitTransactionAsync(string txId)
    {
        if (!_transactions.TryRemove(txId, out var ctx))
        {
            throw new KeyNotFoundException($"Transaction '{txId}' not found or already closed.");
        }

        await ctx.Gate.WaitAsync();
        try
        {
            await ctx.Transaction.CommitAsync();
        }
        finally
        {
            ctx.Gate.Release();
            await ctx.DisposeAsync();
        }

        if (ctx.TouchedTables.Count > 0)
        {
            await BroadcastChangesAsync(ctx.TouchedTables, "tx_commit");
        }
    }

    public async Task RollbackTransactionAsync(string txId)
    {
        if (!_transactions.TryRemove(txId, out var ctx))
        {
            return;
        }

        await ctx.Gate.WaitAsync();
        try
        {
            await ctx.Transaction.RollbackAsync();
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Rollback error for transaction {TxId}", txId);
        }
        finally
        {
            ctx.Gate.Release();
            await ctx.DisposeAsync();
        }
    }

    public async Task<QueryResultResponse> QueryAsync(SqlStatementRequest request)
    {
        var translated = SqlDialectTranslator.Translate(request.Sql, appendReturningForInsert: false);
        if (translated.IsNoOpPragma || string.IsNullOrWhiteSpace(translated.Sql))
        {
            return new QueryResultResponse();
        }

        if (!string.IsNullOrWhiteSpace(request.TxId) && _transactions.TryGetValue(request.TxId, out var txCtx))
        {
            await txCtx.Gate.WaitAsync();
            try
            {
                txCtx.LastActivityUtc = DateTime.UtcNow;
                foreach (var t in translated.AffectedTables) txCtx.TouchedTables.Add(t);
                var rows = await ExecuteReaderInternalAsync(txCtx.Connection, txCtx.Transaction, translated.Sql, request.Params);
                return new QueryResultResponse { Rows = rows };
            }
            finally
            {
                txCtx.Gate.Release();
            }
        }
        else
        {
            await using var conn = new NpgsqlConnection(_connectionString);
            await conn.OpenAsync();
            var rows = await ExecuteReaderInternalAsync(conn, null, translated.Sql, request.Params);
            if (translated.AffectedTables.Count > 0)
            {
                await BroadcastChangesAsync(translated.AffectedTables, "query_write");
            }
            return new QueryResultResponse { Rows = rows };
        }
    }

    public async Task<InsertResultResponse> InsertAsync(SqlStatementRequest request)
    {
        var translated = SqlDialectTranslator.Translate(request.Sql, appendReturningForInsert: true);
        if (translated.IsNoOpPragma || string.IsNullOrWhiteSpace(translated.Sql))
        {
            return new InsertResultResponse { LastInsertRowId = 0 };
        }

        if (!string.IsNullOrWhiteSpace(request.TxId) && _transactions.TryGetValue(request.TxId, out var txCtx))
        {
            await txCtx.Gate.WaitAsync();
            try
            {
                txCtx.LastActivityUtc = DateTime.UtcNow;
                foreach (var t in translated.AffectedTables) txCtx.TouchedTables.Add(t);
                var id = await ExecuteInsertInternalAsync(txCtx.Connection, txCtx.Transaction, translated, request.Params);
                return new InsertResultResponse { LastInsertRowId = id };
            }
            finally
            {
                txCtx.Gate.Release();
            }
        }
        else
        {
            await using var conn = new NpgsqlConnection(_connectionString);
            await conn.OpenAsync();
            var id = await ExecuteInsertInternalAsync(conn, null, translated, request.Params);
            if (translated.AffectedTables.Count > 0)
            {
                await BroadcastChangesAsync(translated.AffectedTables, "insert");
            }
            return new InsertResultResponse { LastInsertRowId = id };
        }
    }

    public async Task<ExecuteResultResponse> ExecuteAsync(SqlStatementRequest request)
    {
        var translated = SqlDialectTranslator.Translate(request.Sql, appendReturningForInsert: false);
        if (translated.IsNoOpPragma || string.IsNullOrWhiteSpace(translated.Sql))
        {
            return new ExecuteResultResponse { AffectedRows = 0 };
        }

        if (!string.IsNullOrWhiteSpace(request.TxId) && _transactions.TryGetValue(request.TxId, out var txCtx))
        {
            await txCtx.Gate.WaitAsync();
            try
            {
                txCtx.LastActivityUtc = DateTime.UtcNow;
                foreach (var t in translated.AffectedTables) txCtx.TouchedTables.Add(t);
                var affected = await ExecuteNonQueryInternalAsync(txCtx.Connection, txCtx.Transaction, translated.Sql, request.Params);
                return new ExecuteResultResponse { AffectedRows = affected };
            }
            finally
            {
                txCtx.Gate.Release();
            }
        }
        else
        {
            await using var conn = new NpgsqlConnection(_connectionString);
            await conn.OpenAsync();
            var affected = await ExecuteNonQueryInternalAsync(conn, null, translated.Sql, request.Params);
            if (translated.AffectedTables.Count > 0)
            {
                await BroadcastChangesAsync(translated.AffectedTables, "execute");
            }
            return new ExecuteResultResponse { AffectedRows = affected };
        }
    }

    public async Task<ExecuteResultResponse> ExecuteBatchAsync(SqlBatchRequest request)
    {
        if (request.Statements.Count == 0)
        {
            return new ExecuteResultResponse { AffectedRows = 0 };
        }

        int totalAffected = 0;

        if (!string.IsNullOrWhiteSpace(request.TxId) && _transactions.TryGetValue(request.TxId, out var txCtx))
        {
            await txCtx.Gate.WaitAsync();
            try
            {
                txCtx.LastActivityUtc = DateTime.UtcNow;
                foreach (var stmt in request.Statements)
                {
                    var translated = SqlDialectTranslator.Translate(stmt.Sql, appendReturningForInsert: false);
                    if (translated.IsNoOpPragma || string.IsNullOrWhiteSpace(translated.Sql)) continue;
                    foreach (var t in translated.AffectedTables) txCtx.TouchedTables.Add(t);
                    totalAffected += await ExecuteNonQueryInternalAsync(txCtx.Connection, txCtx.Transaction, translated.Sql, stmt.Params);
                }
                return new ExecuteResultResponse { AffectedRows = totalAffected };
            }
            finally
            {
                txCtx.Gate.Release();
            }
        }
        else
        {
            var touchedTables = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            await using var conn = new NpgsqlConnection(_connectionString);
            await conn.OpenAsync();
            await using var tx = await conn.BeginTransactionAsync();
            try
            {
                foreach (var stmt in request.Statements)
                {
                    var translated = SqlDialectTranslator.Translate(stmt.Sql, appendReturningForInsert: false);
                    if (translated.IsNoOpPragma || string.IsNullOrWhiteSpace(translated.Sql)) continue;
                    foreach (var t in translated.AffectedTables) touchedTables.Add(t);
                    totalAffected += await ExecuteNonQueryInternalAsync(conn, tx, translated.Sql, stmt.Params);
                }
                await tx.CommitAsync();
            }
            catch
            {
                await tx.RollbackAsync();
                throw;
            }

            if (touchedTables.Count > 0)
            {
                await BroadcastChangesAsync(touchedTables, "batch");
            }

            return new ExecuteResultResponse { AffectedRows = totalAffected };
        }
    }

    private static async Task<List<Dictionary<string, object?>>> ExecuteReaderInternalAsync(
        NpgsqlConnection conn,
        NpgsqlTransaction? tx,
        string sql,
        List<SqlParamDto> parameters)
    {
        await using var cmd = new NpgsqlCommand(sql, conn, tx);
        BindParameters(cmd, parameters);

        var rows = new List<Dictionary<string, object?>>();
        await using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            var row = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
            for (int i = 0; i < reader.FieldCount; i++)
            {
                var rawName = reader.GetName(i);
                var colName = PostgresSchemaInitializer.CanonicalColumnNames.TryGetValue(rawName, out var canonical)
                    ? canonical
                    : rawName.ToLowerInvariant();

                if (reader.IsDBNull(i))
                {
                    row[colName] = null;
                    continue;
                }

                var val = reader.GetValue(i);
                row[colName] = val switch
                {
                    DateTime dt => dt.ToString("O"),
                    DateTimeOffset dto => dto.ToString("O"),
                    decimal dec => (double)dec,
                    _ => val
                };
            }
            rows.Add(row);
        }

        return rows;
    }

    private static async Task<long> ExecuteInsertInternalAsync(
        NpgsqlConnection conn,
        NpgsqlTransaction? tx,
        TranslatedSqlCommand translated,
        List<SqlParamDto> parameters)
    {
        await using var cmd = new NpgsqlCommand(translated.Sql, conn, tx);
        BindParameters(cmd, parameters);

        if (translated.ReturningPrimaryKeyColumn != null)
        {
            var scalar = await cmd.ExecuteScalarAsync();
            if (scalar != null && scalar != DBNull.Value)
            {
                return Convert.ToInt64(scalar);
            }
            return 0L;
        }

        return await cmd.ExecuteNonQueryAsync();
    }

    private static async Task<int> ExecuteNonQueryInternalAsync(
        NpgsqlConnection conn,
        NpgsqlTransaction? tx,
        string sql,
        List<SqlParamDto> parameters)
    {
        await using var cmd = new NpgsqlCommand(sql, conn, tx);
        BindParameters(cmd, parameters);
        return await cmd.ExecuteNonQueryAsync();
    }

    private static void BindParameters(NpgsqlCommand cmd, List<SqlParamDto>? parameters)
    {
        if (parameters == null || parameters.Count == 0) return;

        for (int i = 0; i < parameters.Count; i++)
        {
            var p = parameters[i];
            var paramName = $"@p{i}";
            var type = (p.Type ?? "null").ToLowerInvariant();

            if (type == "null" || p.Value == null || p.Value.Value.ValueKind == JsonValueKind.Null)
            {
                cmd.Parameters.AddWithValue(paramName, DBNull.Value);
                continue;
            }

            var elem = p.Value.Value;
            switch (type)
            {
                case "int":
                case "integer":
                    cmd.Parameters.AddWithValue(paramName, elem.GetInt64());
                    break;
                case "double":
                case "float":
                case "real":
                case "num":
                    cmd.Parameters.AddWithValue(paramName, elem.GetDouble());
                    break;
                case "bool":
                case "boolean":
                    cmd.Parameters.AddWithValue(paramName, elem.GetBoolean());
                    break;
                case "bytes":
                case "blob":
                    var base64 = elem.GetString() ?? string.Empty;
                    cmd.Parameters.AddWithValue(paramName, Convert.FromBase64String(base64));
                    break;
                default:
                    cmd.Parameters.AddWithValue(paramName, elem.ToString());
                    break;
            }
        }
    }

    public async Task<byte[]> ExportToSqliteBytesAsync()
    {
        var tempSqlitePath = Path.Combine(Path.GetTempPath(), $"abona_flemoon_export_{Guid.NewGuid():N}.db");
        try
        {
            await using (var sqliteConn = new SqliteConnection($"Data Source={tempSqlitePath};Mode=ReadWriteCreate"))
            {
                await sqliteConn.OpenAsync();
                await CreateSqliteSchemaForExportAsync(sqliteConn);

                await using var pgConn = new NpgsqlConnection(_connectionString);
                await pgConn.OpenAsync();

                await using var sqliteTx = await sqliteConn.BeginTransactionAsync();
                foreach (var table in PostgresSchemaInitializer.OrderedTables)
                {
                    await using var pgCmd = new NpgsqlCommand($"SELECT * FROM \"{table}\";", pgConn);
                    await using var reader = await pgCmd.ExecuteReaderAsync();

                    if (!reader.HasRows) continue;

                    var cols = new List<string>();
                    for (int i = 0; i < reader.FieldCount; i++)
                    {
                        cols.Add(reader.GetName(i));
                    }

                    var colNamesSql = string.Join(", ", cols.Select(c => $"\"{c}\""));
                    var paramNamesSql = string.Join(", ", cols.Select((_, i) => $"@p{i}"));
                    var insertSql = $"INSERT INTO \"{table}\" ({colNamesSql}) VALUES ({paramNamesSql});";

                    while (await reader.ReadAsync())
                    {
                        await using var insertCmd = sqliteConn.CreateCommand();
                        insertCmd.Transaction = (SqliteTransaction)sqliteTx;
                        insertCmd.CommandText = insertSql;

                        for (int i = 0; i < cols.Count; i++)
                        {
                            var val = reader.IsDBNull(i) ? DBNull.Value : reader.GetValue(i);
                            insertCmd.Parameters.AddWithValue($"@p{i}", val);
                        }
                        await insertCmd.ExecuteNonQueryAsync();
                    }
                }
                await sqliteTx.CommitAsync();
            }

            SqliteConnection.ClearAllPools();
            return await File.ReadAllBytesAsync(tempSqlitePath);
        }
        finally
        {
            SqliteConnection.ClearAllPools();
            if (File.Exists(tempSqlitePath))
            {
                try { File.Delete(tempSqlitePath); } catch { }
            }
        }
    }

    public async Task ImportFromSqliteBytesAsync(byte[] sqliteBytes)
    {
        var tempSqlitePath = Path.Combine(Path.GetTempPath(), $"abona_flemoon_import_{Guid.NewGuid():N}.db");
        try
        {
            await File.WriteAllBytesAsync(tempSqlitePath, sqliteBytes);
            await using var pgConn = new NpgsqlConnection(_connectionString);
            await pgConn.OpenAsync();
            await PostgresSchemaInitializer.ImportFromSqliteFileInternalAsync(pgConn, tempSqlitePath, _logger);
            await BroadcastChangesAsync(PostgresSchemaInitializer.OrderedTables, "sqlite_import");
        }
        finally
        {
            SqliteConnection.ClearAllPools();
            if (File.Exists(tempSqlitePath))
            {
                try { File.Delete(tempSqlitePath); } catch { }
            }
        }
    }

    private static async Task CreateSqliteSchemaForExportAsync(SqliteConnection sqliteConn)
    {
        const string sqliteDdl = @"
CREATE TABLE IF NOT EXISTS areas (area_id INTEGER PRIMARY KEY AUTOINCREMENT, area_name TEXT NOT NULL UNIQUE);
CREATE TABLE IF NOT EXISTS streets (street_id INTEGER PRIMARY KEY AUTOINCREMENT, street_name TEXT NOT NULL, area_id INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS karaba (karaba_id INTEGER PRIMARY KEY AUTOINCREMENT, karaba_name TEXT NOT NULL UNIQUE);
CREATE TABLE IF NOT EXISTS mostwa (mostwa_id INTEGER PRIMARY KEY AUTOINCREMENT, mostwa_name TEXT NOT NULL UNIQUE);
CREATE TABLE IF NOT EXISTS hala_egtimaia (hala_egtimaia_id INTEGER PRIMARY KEY AUTOINCREMENT, hala_name TEXT NOT NULL UNIQUE);
CREATE TABLE IF NOT EXISTS hala_sehia (hala_sehia_id INTEGER PRIMARY KEY AUTOINCREMENT, hala_name TEXT NOT NULL UNIQUE);
CREATE TABLE IF NOT EXISTS e_s (e_s_id INTEGER PRIMARY KEY AUTOINCREMENT, e_s_name TEXT NOT NULL UNIQUE);
CREATE TABLE IF NOT EXISTS stage (stage_id INTEGER PRIMARY KEY AUTOINCREMENT, stage_name TEXT NOT NULL UNIQUE);
CREATE TABLE IF NOT EXISTS fathers (father_id INTEGER PRIMARY KEY AUTOINCREMENT, father_name TEXT NOT NULL, father_mobile TEXT, birth_date TEXT);
CREATE TABLE IF NOT EXISTS khdma (khdma_id INTEGER PRIMARY KEY AUTOINCREMENT, khdma_name TEXT NOT NULL UNIQUE);
CREATE TABLE IF NOT EXISTS users (pass_id INTEGER PRIMARY KEY AUTOINCREMENT, user_name TEXT NOT NULL UNIQUE, pass_word TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS icon (icon_id INTEGER PRIMARY KEY AUTOINCREMENT, icon_name TEXT NOT NULL UNIQUE);
CREATE TABLE IF NOT EXISTS inter_icon (inter_id INTEGER PRIMARY KEY AUTOINCREMENT, pass_id INTEGER NOT NULL, icon_id INTEGER, icon_name TEXT, check_1 INTEGER DEFAULT 1);
CREATE TABLE IF NOT EXISTS settings (setting_key TEXT PRIMARY KEY, setting_value TEXT);
CREATE TABLE IF NOT EXISTS osra (birth_date TEXT, age TEXT, gender TEXT, governorate TEXT, osra_id INTEGER PRIMARY KEY AUTOINCREMENT, osra_name TEXT NOT NULL, karaba_id INTEGER, e_s_id INTEGER, area_id INTEGER, street_id INTEGER, dalil_name TEXT, emara TEXT, door TEXT, shaka TEXT, r_o TEXT, phone TEXT, number INTEGER DEFAULT 0, hala_egtimaia_id INTEGER, rakm_komy TEXT, code INTEGER, hala_sehia_id INTEGER, mostwa_id INTEGER);
CREATE TABLE IF NOT EXISTS person (gender TEXT, governorate TEXT, person_id INTEGER PRIMARY KEY AUTOINCREMENT, person_name TEXT NOT NULL, osra_id INTEGER NOT NULL, karaba_id INTEGER, birth_date TEXT, mostwa_id INTEGER, moahil TEXT, date_moiahil TEXT, hala_egtimaia_id INTEGER, hala_sehia_id INTEGER, wazefa TEXT, place_work TEXT, mobile TEXT, facebook TEXT, father TEXT, stage_id INTEGER, father_id INTEGER, month TEXT, age TEXT, rakm_komy TEXT);
CREATE TABLE IF NOT EXISTS eatraf (eatraf_id INTEGER PRIMARY KEY AUTOINCREMENT, person_id INTEGER NOT NULL, date TEXT NOT NULL, notes TEXT);
CREATE TABLE IF NOT EXISTS visits (visit_id INTEGER PRIMARY KEY AUTOINCREMENT, osra_id INTEGER NOT NULL, date TEXT NOT NULL, notes TEXT);
CREATE TABLE IF NOT EXISTS monasba (monasba_id INTEGER PRIMARY KEY AUTOINCREMENT, osra_id INTEGER NOT NULL, monasba_name TEXT NOT NULL, monasba_date TEXT, month TEXT);
CREATE TABLE IF NOT EXISTS count_aid (count_id INTEGER PRIMARY KEY AUTOINCREMENT, osra_id INTEGER NOT NULL, khdma_id INTEGER, count_value REAL DEFAULT 0, aynee TEXT, notes TEXT);
CREATE TABLE IF NOT EXISTS count_2 (count_2_id INTEGER PRIMARY KEY AUTOINCREMENT, osra_id INTEGER NOT NULL, type TEXT, count_add REAL DEFAULT 0, notes TEXT, date_1 TEXT);
CREATE TABLE IF NOT EXISTS masrofat (masrofat_id INTEGER PRIMARY KEY AUTOINCREMENT, osra_id INTEGER NOT NULL, masrof TEXT, count_value REAL DEFAULT 0, aynee TEXT, notes TEXT);
PRAGMA user_version = 11;
";
        await using var cmd = sqliteConn.CreateCommand();
        cmd.CommandText = sqliteDdl;
        await cmd.ExecuteNonQueryAsync();
    }

    public async Task BroadcastChangesAsync(IEnumerable<string> tables, string operation)
    {
        var list = tables
            .Where(t => !string.IsNullOrWhiteSpace(t))
            .Select(t => t.ToLowerInvariant())
            .Distinct()
            .ToList();

        if (list.Count == 0) return;

        var payload = new DatabaseChangeNotification
        {
            Tables = list,
            Operation = operation,
            TimestampUtc = DateTime.UtcNow
        };

        await _hubContext.Clients.All.SendAsync("DatabaseChanged", payload);
    }

    private void CleanupStaleTransactions(object? state)
    {
        var cutoff = DateTime.UtcNow.AddSeconds(-90);
        foreach (var kvp in _transactions)
        {
            if (kvp.Value.LastActivityUtc < cutoff)
            {
                if (_transactions.TryRemove(kvp.Key, out var stale))
                {
                    _logger.LogWarning("Rolling back stale transaction {TxId}", kvp.Key);
                    _ = Task.Run(async () =>
                    {
                        try { await stale.Transaction.RollbackAsync(); } catch { }
                        try { await stale.DisposeAsync(); } catch { }
                    });
                }
            }
        }
    }

    public void Dispose()
    {
        _cleanupTimer.Dispose();
    }
}
