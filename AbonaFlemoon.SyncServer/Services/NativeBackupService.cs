using System.Diagnostics;
using System.Text.Json;
using Npgsql;

namespace DatabaseBackups;

public sealed record BackupSettings(bool Enabled, string Directory, int Retention = 30,
    DateTimeOffset? LastSuccessUtc = null, string? LastPath = null, string? LastError = null);

// Shared implementation copied into each independently distributable server.
public sealed class NativeBackupService : BackgroundService
{
    private readonly SemaphoreSlim _gate = new(1, 1);
    private readonly string _connectionString, _prefix, _root, _bin;
    private readonly ILogger<NativeBackupService> _logger;
    private BackupSettings _settings;
    private readonly JsonSerializerOptions _json = new(JsonSerializerDefaults.Web);
    public NativeBackupService(string connectionString, string prefix, ILogger<NativeBackupService> logger)
    {
        _connectionString = connectionString;
        _prefix = prefix;
        _logger = logger;
        _root = Environment.GetEnvironmentVariable("BACKUP_SETTINGS_ROOT")
            ?? Path.Combine(AppContext.BaseDirectory, "backup-state");
        _bin = Environment.GetEnvironmentVariable("POSTGRES_BIN")
            ?? Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", "postgresql", "bin"));
        _settings = new(true, Environment.GetEnvironmentVariable("BACKUP_DEFAULT_DIRECTORY")
            ?? Path.Combine(_root, "backups"));
        try
        {
            if (File.Exists(SettingsPath))
                _settings = JsonSerializer.Deserialize<BackupSettings>(File.ReadAllText(SettingsPath), _json) ?? _settings;
        }
        catch (Exception ex) { _settings = _settings with { LastError = ex.Message }; _logger.LogError(ex, "Could not read backup settings"); }
    }
    private string SettingsPath => Path.Combine(_root, "backup-settings.json");
    public BackupSettings Settings => _settings;
    public string ConnectionString => _connectionString;

    private async Task SaveStateAsync()
    {
        Directory.CreateDirectory(_root);
        var temp = SettingsPath + ".tmp";
        await File.WriteAllTextAsync(temp, JsonSerializer.Serialize(_settings, _json));
        File.Move(temp, SettingsPath, true);
    }
    public async Task<BackupSettings> ConfigureAsync(BackupSettings value)
    {
        if (value.Retention is < 1 or > 365) throw new ArgumentException("عدد النسخ يجب أن يكون من 1 إلى 365.");
        if (string.IsNullOrWhiteSpace(value.Directory) || !Path.IsPathFullyQualified(value.Directory))
            throw new ArgumentException("اختر مسارًا كاملاً لمجلد النسخ على جهاز السيرفر.");
        await _gate.WaitAsync();
        try
        {
            var directory = Path.GetFullPath(value.Directory);
            Directory.CreateDirectory(directory);
            var probe = Path.Combine(directory, $".backup-write-test-{Guid.NewGuid():N}");
            await File.WriteAllTextAsync(probe, "test");
            File.Delete(probe);
            var previous = _settings;
            _settings = _settings with { Enabled = value.Enabled, Directory = directory, Retention = value.Retention, LastError = null,
                LastSuccessUtc = directory == _settings.Directory ? _settings.LastSuccessUtc : null };
            try { await SaveStateAsync(); }
            catch { _settings = previous; throw; }
            return _settings;
        }
        finally { _gate.Release(); }
    }
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        // Run independently of the Flutter client; catch up after a shutdown.
        await Task.Delay(TimeSpan.FromSeconds(10), stoppingToken);
        while (!stoppingToken.IsCancellationRequested)
        {
            try { await CreateAsync(automatic: true, onlyIfDue: true, stoppingToken); }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { break; }
            catch (Exception ex) { _logger.LogError(ex, "Automatic PostgreSQL backup failed"); }
            await Task.Delay(TimeSpan.FromMinutes(15), stoppingToken);
        }
    }
    public async Task<string?> CreateAsync(bool automatic, bool onlyIfDue = false, CancellationToken token = default)
    {
        await _gate.WaitAsync(token);
        string? partial = null;
        try
        {
            if (onlyIfDue && (!_settings.Enabled ||
                _settings.LastSuccessUtc is {} last && DateTimeOffset.UtcNow - last < TimeSpan.FromDays(1))) return null;
            var directory = automatic ? _settings.Directory : Path.Combine(_root, "downloads");
            Directory.CreateDirectory(directory);
            var tag = automatic ? "auto" : "manual";
            var target = Path.Combine(directory, $"{_prefix}_postgresql_{tag}_{DateTime.UtcNow:yyyyMMdd_HHmmss_fff}_{Guid.NewGuid():N}.dump");
            partial = target + ".partial";
            await RunToolAsync("pg_dump", ["--format=custom", "--no-owner", "--no-privileges", "--file", partial], token);
            await ValidateArchiveAsync(partial, token);
            File.Move(partial, target);
            partial = null;
            if (automatic)
            {
                _settings = _settings with { LastSuccessUtc = DateTimeOffset.UtcNow, LastPath = target, LastError = null };
                await SaveStateAsync();
                // Only our successful automatic dumps participate in retention.
                foreach (var old in new DirectoryInfo(directory).GetFiles($"{_prefix}_postgresql_auto_*.dump")
                    .OrderByDescending(f => f.Name, StringComparer.Ordinal).Skip(_settings.Retention)) old.Delete();
            }
            return target;
        }
        catch (Exception ex)
        {
            if (automatic)
            {
                _settings = _settings with { LastError = ex.Message };
                try { await SaveStateAsync(); } catch (Exception saveError) { _logger.LogError(saveError, "Could not save backup failure status"); }
            }
            throw;
        }
        finally
        {
            if (partial is not null && File.Exists(partial)) File.Delete(partial);
            _gate.Release();
        }
    }
    public async Task RestoreAsync(string archive, CancellationToken token)
    {
        await ValidateArchiveAsync(archive, token);
        // Never prune this safety copy as part of automatic retention.
        var safety = await CreateAsync(automatic: false, token: token);
        var recoveryDirectory = Path.Combine(_settings.Directory, "before-restore");
        Directory.CreateDirectory(recoveryDirectory);
        File.Move(safety!, Path.Combine(recoveryDirectory, Path.GetFileName(safety!)));
        await _gate.WaitAsync(token);
        try
        {
            // Restore is atomic: any SQL error rolls the entire operation back.
            await RunToolAsync("pg_restore", ["--clean", "--if-exists", "--no-owner", "--no-privileges",
                "--single-transaction", "--exit-on-error", "--dbname", new NpgsqlConnectionStringBuilder(_connectionString).Database!, archive], token);
            NpgsqlConnection.ClearAllPools();
        }
        finally { _gate.Release(); }
    }
    private async Task ValidateArchiveAsync(string path, CancellationToken token)
    {
        await using var file = File.OpenRead(path);
        var magic = new byte[5];
        if (await file.ReadAsync(magic, token) != 5 || !magic.SequenceEqual("PGDMP"u8.ToArray()))
            throw new InvalidDataException("الملف ليس نسخة PostgreSQL بصيغة dump.");
        await RunToolAsync("pg_restore", ["--list", path], token, connect: false);
    }
    private async Task RunToolAsync(string tool, IEnumerable<string> arguments, CancellationToken token, bool connect = true)
    {
        var executable = Path.Combine(_bin, tool + (OperatingSystem.IsWindows() ? ".exe" : ""));
        if (!File.Exists(executable)) throw new FileNotFoundException($"أداة {tool} غير موجودة. حدّث تثبيت مكوّن السيرفر.");
        var start = new ProcessStartInfo(executable)
        {
            UseShellExecute = false, CreateNoWindow = true,
            RedirectStandardError = true, RedirectStandardOutput = true,
        };
        // Passwords never enter process arguments or logs.
        var connection = new NpgsqlConnectionStringBuilder(_connectionString);
        if (connect)
        {
            start.Environment["PGHOST"] = connection.Host!;
            start.Environment["PGPORT"] = connection.Port.ToString();
            start.Environment["PGUSER"] = connection.Username!;
            start.Environment["PGPASSWORD"] = connection.Password ?? "";
            start.Environment["PGDATABASE"] = connection.Database!;
            start.Environment["PGCONNECT_TIMEOUT"] = "15";
        }
        foreach (var arg in arguments) start.ArgumentList.Add(arg);
        using var process = Process.Start(start) ?? throw new IOException($"تعذر تشغيل {tool}.");
        var stdout = process.StandardOutput.ReadToEndAsync();
        var stderr = process.StandardError.ReadToEndAsync();
        using var limit = CancellationTokenSource.CreateLinkedTokenSource(token);
        limit.CancelAfter(TimeSpan.FromMinutes(30));
        try { await process.WaitForExitAsync(limit.Token); }
        catch { if (!process.HasExited) process.Kill(entireProcessTree: true); await process.WaitForExitAsync(); throw; }
        await stdout;
        var error = await stderr;
        if (process.ExitCode != 0) throw new IOException($"{tool} فشل (كود {process.ExitCode}): {error}");
    }
}
