using DatabaseBackups;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using AbonaFlemoon.SyncServer.Services;

namespace AbonaFlemoon.SyncServer.Controllers;

[ApiController, Route("api/backups")]
public sealed class BackupsController(NativeBackupService backups, StorageService storage) : ControllerBase
{
    private async Task<bool> Allowed()
    {
        var auth = Request.Headers.Authorization.ToString();
        if (!auth.StartsWith("Basic ", StringComparison.Ordinal)) return false;
        string raw;
        try { raw = System.Text.Encoding.UTF8.GetString(Convert.FromBase64String(auth[6..])); }
        catch (FormatException) { return false; }
        var split = raw.IndexOf(':');
        if (split < 0) return false;
        await using var connection = new Npgsql.NpgsqlConnection(backups.ConnectionString);
        await connection.OpenAsync();
        await using var command = new Npgsql.NpgsqlCommand("""
            SELECT EXISTS (SELECT 1 FROM users u WHERE user_name = @name AND pass_word = @password
              AND (pass_id = 1 OR EXISTS (SELECT 1 FROM inter_icon ii LEFT JOIN icon i ON i.icon_id = ii.icon_id
                WHERE ii.pass_id = u.pass_id AND ii.check_1 = 1 AND COALESCE(i.icon_name, ii.icon_name) = 'صيانة النظام')))
            """, connection);
        command.Parameters.AddWithValue("name", raw[..split]);
        command.Parameters.AddWithValue("password", raw[(split + 1)..]);
        return (bool)(await command.ExecuteScalarAsync())!;
    }
    [HttpGet("settings")]
    public async Task<IActionResult> Settings() => await Allowed() ? Ok(backups.Settings) : StatusCode(403);
    [HttpPut("settings")]
    public async Task<IActionResult> Configure(BackupSettings settings)
    {
        if (!await Allowed()) return StatusCode(403);
        try { return Ok(await backups.ConfigureAsync(settings)); }
        catch (Exception ex) { return BadRequest(new { error = ex.Message }); }
    }
    [HttpPost("run")]
    public async Task<IActionResult> Run(CancellationToken token)
    {
        if (!await Allowed()) return StatusCode(403);
        try { await backups.CreateAsync(true, token: token); return Ok(backups.Settings); }
        catch (Exception ex) { return BadRequest(new { error = ex.Message }); }
    }
    [HttpGet("download")]
    public async Task<IActionResult> Download(CancellationToken token)
    {
        if (!await Allowed()) return StatusCode(403);
        var path = await backups.CreateAsync(false, token: token);
        var stream = new FileStream(path!, FileMode.Open, FileAccess.Read, FileShare.Read, 81920, FileOptions.DeleteOnClose);
        return File(stream, "application/octet-stream", Path.GetFileName(path));
    }
    [HttpPost("restore"), RequestSizeLimit(2L * 1024 * 1024 * 1024)]
    public async Task<IActionResult> Restore(CancellationToken token)
    {
        if (!await Allowed()) return StatusCode(403);
        var path = Path.Combine(Path.GetTempPath(), $"restore-{Guid.NewGuid():N}.dump");
        try
        {
            await using (var file = System.IO.File.Create(path)) await Request.Body.CopyToAsync(file, token);
            await backups.RestoreAsync(path, token);

            await storage.BroadcastChangesAsync(PostgresSchemaInitializer.OrderedTables, "restore_postgresql");
            return Ok(new { status = "ok" });
        }
        catch (Exception ex) { return BadRequest(new { error = ex.Message }); }
        finally { if (System.IO.File.Exists(path)) System.IO.File.Delete(path); }
    }
}
