using System.Diagnostics;
using System.Net;
using System.Net.NetworkInformation;
using System.Net.Sockets;
using System.Text;
using System.Text.Json;
using Microsoft.Win32;

namespace AbonaFlemoonServerManager;

internal enum ServerState
{
    Stopped,
    Starting,
    Running,
    Stopping,
    Recovering,
    Failed,
}

internal sealed class ServerStatusEventArgs(ServerState state, string message) : EventArgs
{
    public ServerState State { get; } = state;
    public string Message { get; } = message;
}

internal sealed class ServerSupervisor : IDisposable
{
    public const int ApiPort = 5060;
    public const int DatabasePort = 5438;
    public const string DatabaseName = "church_membership";
    private const string AutoStartRegistryKey = @"Software\Microsoft\Windows\CurrentVersion\Run";
    private const string AutoStartValueName = "AbonaFlemoonServerManager";

    private readonly SemaphoreSlim _operationLock = new(1, 1);
    private readonly HttpClient _http;
    private readonly System.Threading.Timer _watchdog;
    private readonly object _logLock = new();
    private readonly int _apiPort;
    private readonly int _databasePort;
    private Process? _postgres;
    private Process? _backend;
    private bool _desiredRunning;
    private bool _disposed;

    public ServerSupervisor(string installRoot, int apiPort = ApiPort, int databasePort = DatabasePort, string? dataRoot = null)
    {
        _apiPort = apiPort;
        _databasePort = databasePort;
        InstallRoot = Path.GetFullPath(installRoot).TrimEnd(Path.DirectorySeparatorChar);
        ServerRoot = Path.Combine(InstallRoot, "server");
        if (!Directory.Exists(ServerRoot) && Directory.Exists(Path.Combine(InstallRoot, "Server")))
        {
            ServerRoot = Path.Combine(InstallRoot, "Server");
        }

        ServerData = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "ChurchMembership_ServerData");
        var legacyData = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "AbonaFlemoon_ServerData");
        if (!File.Exists(Path.Combine(ServerData, "pgdata", "PG_VERSION")) && File.Exists(Path.Combine(legacyData, "pgdata", "PG_VERSION"))) ServerData = legacyData;
        if (dataRoot is not null) ServerData = Path.GetFullPath(dataRoot);
        Directory.CreateDirectory(ServerData);
        LogsRoot = Path.Combine(ServerData, "logs");
        Directory.CreateDirectory(LogsRoot);
        ManagerLogPath = Path.Combine(LogsRoot, "server-manager.log");

        var handler = new HttpClientHandler
        {
            UseProxy = false,
            ServerCertificateCustomValidationCallback = (_, _, _, _) => true,
        };
        _http = new HttpClient(handler) { Timeout = TimeSpan.FromSeconds(3) };
        _watchdog = new System.Threading.Timer(
            WatchdogTick,
            null,
            TimeSpan.FromSeconds(8),
            TimeSpan.FromSeconds(8));
    }

    public event EventHandler<ServerStatusEventArgs>? StatusChanged;
    public event EventHandler<string>? LogReceived;

    public string InstallRoot { get; }
    public string ServerRoot { get; }
    public string ServerData { get; }
    public string LogsRoot { get; }
    public string ManagerLogPath { get; }
    public string LocalUrl => $"http://127.0.0.1:{_apiPort}";

    public IReadOnlyList<string> NetworkUrls => GetLanAddresses()
        .Select(address => $"http://{address}:{_apiPort}")
        .ToList();

    private string BackendPidPath => Path.Combine(ServerData, "backend-manager.pid");
    private string PostgresDataDir => Path.Combine(ServerData, "pgdata");

    public async Task StartAsync(bool recovering = false)
    {
        _desiredRunning = true;
        await _operationLock.WaitAsync();
        try
        {
            if (await IsHealthyAsync())
            {
                WriteServerInfoFile();
                Publish(ServerState.Running, "السيرفر يعمل وقاعدة البيانات PostgreSQL متصلة (SignalR نشط على منفذ 5060)");
                return;
            }

            Publish(
                recovering ? ServerState.Recovering : ServerState.Starting,
                recovering
                    ? "جاري استعادة تشغيل السيرفر وقاعدة البيانات تلقائيًا..."
                    : $"جاري تشغيل محرك قاعدة البيانات PostgreSQL (منفذ {_databasePort})...");

            var (postgresBinDir, backendExePath) = ResolveBinaries();
            await StopOwnedProcessesAsync(postgresBinDir);
            RemoveStalePostmasterPid();

            await EnsurePostgresClusterInitializedAsync(postgresBinDir, PostgresDataDir);

            // Check if port 5438 is already open
            if (!await IsPortOpenAsync(_databasePort))
            {
                var postgresExe = Path.Combine(postgresBinDir, "postgres.exe");
                _postgres = StartProcess(
                    postgresExe,
                    postgresBinDir,
                    "postgres",
                    null,
                    "-D", PostgresDataDir,
                    "-p", _databasePort.ToString(),
                    "-h", "127.0.0.1");

            }

            await WaitForPostgresAsync(postgresBinDir, TimeSpan.FromMinutes(3));

            Publish(ServerState.Starting, "قاعدة البيانات جاهزة — جاري تشغيل سيرفر التزامن .NET 8 (منفذ 5060)...");
            var backendWorkDir = Path.GetDirectoryName(backendExePath)!;
            var envVars = new Dictionary<string, string>
            {
                ["PORT"] = _apiPort.ToString(),
                ["POSTGRES_BIN"] = postgresBinDir,
                ["BACKUP_SETTINGS_ROOT"] = ServerData,
                ["BACKUP_DEFAULT_DIRECTORY"] = Path.Combine(InstallRoot, "ChurchMembership_ServerBackups"),
                ["ASPNETCORE_URLS"] = $"http://0.0.0.0:{_apiPort}",
                ["ConnectionStrings__Postgres"] = $"Host=127.0.0.1;Port={_databasePort};Database={DatabaseName};Username=postgres;Password=postgres;Pooling=true;MinPoolSize=2;MaxPoolSize=100;",
            };

            _backend = StartProcess(
                backendExePath,
                backendWorkDir,
                "dotnet-server",
                envVars);
            File.WriteAllText(BackendPidPath, _backend.Id.ToString(), new UTF8Encoding(false));

            if (!await WaitForHealthAsync(_backend, TimeSpan.FromMinutes(5)))
            {
                throw new InvalidOperationException(
                    _backend.HasExited
                        ? $"توقف سيرفر .NET أثناء التشغيل (ExitCode={_backend.ExitCode}). راجع سجل مدير السيرفر."
                        : "لم يجهز سيرفر .NET خلال خمس دقائق. راجع سجل مدير السيرفر ثم أعد المحاولة.");
            }

            WriteServerInfoFile();
            Publish(ServerState.Running, "السيرفر يعمل وقاعدة البيانات PostgreSQL متصلة (SignalR نشط على منفذ 5060)");
        }
        catch (Exception exception)
        {
            WriteLog("manager", exception.ToString());
            Publish(ServerState.Failed, exception.Message);
        }
        finally
        {
            _operationLock.Release();
        }
    }

    public async Task StopAsync()
    {
        _desiredRunning = false;
        await _operationLock.WaitAsync();
        try
        {
            Publish(ServerState.Stopping, "جاري إيقاف السيرفر وقاعدة البيانات بأمان...");
            var (postgresBinDir, _) = TryResolveBinaries();
            await StopOwnedProcessesAsync(postgresBinDir);
            Publish(ServerState.Stopped, "السيرفر وقاعدة البيانات متوقفان");
        }
        catch (Exception exception)
        {
            WriteLog("manager", exception.ToString());
            Publish(ServerState.Failed, exception.Message);
        }
        finally
        {
            _operationLock.Release();
        }
    }

    public async Task RestartAsync()
    {
        await StopAsync();
        await StartAsync();
    }

    public async Task<bool> IsHealthyAsync()
    {
        try
        {
            using var response = await _http.GetAsync($"{LocalUrl}/api/auth/ping");
            if (!response.IsSuccessStatusCode) return false;
            await using var stream = await response.Content.ReadAsStreamAsync();
            using var json = await JsonDocument.ParseAsync(stream);
            return json.RootElement.TryGetProperty("status", out var status)
                && status.GetString()?.Equals("ok", StringComparison.OrdinalIgnoreCase) == true;
        }
        catch
        {
            return false;
        }
    }

    public bool IsAutoStartEnabled()
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(AutoStartRegistryKey, false);
            return key?.GetValue(AutoStartValueName) != null;
        }
        catch
        {
            return false;
        }
    }

    public void SetAutoStartWithWindows(bool enable)
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(AutoStartRegistryKey, true);
            if (key == null) return;
            if (enable)
            {
                var exePath = Process.GetCurrentProcess().MainModule?.FileName ??
                              Path.Combine(AppContext.BaseDirectory, "ChurchMembershipServerManager.exe");
                key.SetValue(AutoStartValueName, $"\"{exePath}\" --background --install-root \"{InstallRoot}\"");
            }
            else
            {
                key.DeleteValue(AutoStartValueName, false);
            }
        }
        catch (Exception ex)
        {
            WriteLog("manager", $"فشل تعديل بدء التشغيل التلقائي: {ex.Message}");
        }
    }

    private (string? PostgresBinDir, string? BackendExePath) TryResolveBinaries()
    {
        var pgCandidates = new List<string>
        {
            Path.Combine(ServerRoot, "postgresql", "bin"),
            Path.Combine(ServerRoot, "pgsql", "bin"),
            Path.Combine(InstallRoot, "Server", "postgresql", "bin"),
            Path.Combine(InstallRoot, "pgsql", "bin"),
            Path.Combine(InstallRoot, "postgresql", "bin"),
            Path.Combine(InstallRoot, "build", "installer_staging", "pgsql", "bin"),
            Path.Combine(AppContext.BaseDirectory, "pgsql", "bin"),
        };
        var pgBin = pgCandidates.FirstOrDefault(dir => File.Exists(Path.Combine(dir, "postgres.exe")));

        var backendCandidates = new List<string>
        {
            Path.Combine(ServerRoot, "backend", "ChurchMembership.SyncServer.exe"),
            Path.Combine(InstallRoot, "Server", "backend", "ChurchMembership.SyncServer.exe"),
            Path.Combine(ServerRoot, "ChurchMembership.SyncServer.exe"),
            Path.Combine(InstallRoot, "server", "ChurchMembership.SyncServer.exe"),
            Path.Combine(InstallRoot, "Server", "ChurchMembership.SyncServer.exe"),
            Path.Combine(InstallRoot, "build", "installer_staging", "server", "ChurchMembership.SyncServer.exe"),
            Path.Combine(InstallRoot, "AbonaFlemoon.SyncServer", "bin", "Release", "net8.0", "win-x64", "ChurchMembership.SyncServer.exe"),
            Path.Combine(InstallRoot, "AbonaFlemoon.SyncServer", "bin", "Release", "net8.0", "ChurchMembership.SyncServer.exe"),
            Path.Combine(InstallRoot, "AbonaFlemoon.SyncServer", "bin", "Debug", "net8.0", "ChurchMembership.SyncServer.exe"),
            Path.Combine(AppContext.BaseDirectory, "server", "ChurchMembership.SyncServer.exe"),
            Path.Combine(AppContext.BaseDirectory, "ChurchMembership.SyncServer.exe"),
        };
        var backendExe = backendCandidates.FirstOrDefault(File.Exists);

        return (pgBin, backendExe);
    }

    private (string PostgresBinDir, string BackendExePath) ResolveBinaries()
    {
        var (pgBin, backendExe) = TryResolveBinaries();
        if (string.IsNullOrWhiteSpace(pgBin))
        {
            throw new FileNotFoundException(
                "لم يتم العثور على محرك قاعدة البيانات PostgreSQL (postgres.exe). تأكد من وجود مجلد pgsql/bin بجانب السيرفر.");
        }
        if (string.IsNullOrWhiteSpace(backendExe))
        {
            throw new FileNotFoundException(
                "لم يتم العثور على ملف سيرفر التزامن ChurchMembership.SyncServer.exe.");
        }
        return (pgBin, backendExe);
    }

    private async Task EnsurePostgresClusterInitializedAsync(string postgresBinDir, string postgresData)
    {
        var pgVersionFile = Path.Combine(postgresData, "PG_VERSION");
        if (File.Exists(pgVersionFile)) return;

        Directory.CreateDirectory(postgresData);
        var initDbExe = Path.Combine(postgresBinDir, "initdb.exe");
        if (!File.Exists(initDbExe))
        {
            throw new FileNotFoundException("ملف initdb.exe غير موجود لتهيئة قاعدة البيانات.", initDbExe);
        }

        WriteLog("manager", "جاري تهيئة عنقود بيانات PostgreSQL لأول مرة (initdb)...");
        var start = new ProcessStartInfo
        {
            FileName = initDbExe,
            WorkingDirectory = postgresBinDir,
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
        };
        foreach (var arg in new[] { "-D", postgresData, "-U", "postgres", "-E", "UTF8", "--locale=C", "--auth=trust" })
        {
            start.ArgumentList.Add(arg);
        }

        using var proc = Process.Start(start)
            ?? throw new InvalidOperationException("تعذر تشغيل initdb.exe");
        var stdOut = await proc.StandardOutput.ReadToEndAsync();
        var stdErr = await proc.StandardError.ReadToEndAsync();
        await proc.WaitForExitAsync();

        if (!string.IsNullOrWhiteSpace(stdOut)) WriteLog("initdb", stdOut.Trim());
        if (!string.IsNullOrWhiteSpace(stdErr)) WriteLog("initdb", stdErr.Trim());

        if (proc.ExitCode != 0 || !File.Exists(pgVersionFile))
        {
            throw new InvalidOperationException($"فشل تهيئة قاعدة البيانات PostgreSQL (ExitCode={proc.ExitCode}).");
        }
        WriteLog("manager", "تم تهيئة عنقود بيانات PostgreSQL بنجاح في مجلد " + postgresData);
    }

    public void WriteServerInfoFile()
    {
        try
        {
            var lanUrls = NetworkUrls;
            var recommendedLan = lanUrls.FirstOrDefault() ?? LocalUrl;
            var lines = new List<string>
            {
                $"LOCAL_URL={LocalUrl}",
                $"LAN_URL={recommendedLan}",
                $"SIGNALR_HUB={recommendedLan}/hubs/sync",
                $"POSTGRES_PORT={_databasePort}",
                $"DATABASE_NAME={DatabaseName}",
                $"UPDATED_AT={DateTime.Now:O}",
                "",
                "=== Church Membership Sync Server (Church Membership - العضوية الكنسية) ===",
                $"Status: Running",
                $"Local URL (هذا الجهاز): {LocalUrl}",
                $"Recommended LAN URL (للأجهزة والموبايل على نفس الشبكة): {recommendedLan}",
                $"SignalR Sync Hub: {recommendedLan}/hubs/sync",
                $"PostgreSQL Port: {_databasePort}",
                $"Database Name: {DatabaseName}",
                $"Server Time: {DateTime.Now:yyyy-MM-dd HH:mm:ss}",
                "",
                "All Available Network Addresses:",
            };
            lines.AddRange(lanUrls);

            var infoPath = Path.Combine(InstallRoot, "SERVER_INFO.txt");
            File.WriteAllLines(infoPath, lines, new UTF8Encoding(false));

            // Also copy to AppData
            var appDataInfo = Path.Combine(ServerData, "SERVER_INFO.txt");
            File.WriteAllLines(appDataInfo, lines, new UTF8Encoding(false));
        }
        catch (Exception ex)
        {
            WriteLog("manager", $"Could not write SERVER_INFO.txt: {ex.Message}");
        }
    }

    private Process StartProcess(
        string executable,
        string workingDirectory,
        string logPrefix,
        IDictionary<string, string>? environmentVariables,
        params string[] arguments)
    {
        var start = new ProcessStartInfo
        {
            FileName = executable,
            WorkingDirectory = workingDirectory,
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
        };
        if (environmentVariables is not null)
        {
            foreach (var (k, v) in environmentVariables)
            {
                start.EnvironmentVariables[k] = v;
            }
        }
        foreach (var argument in arguments) start.ArgumentList.Add(argument);

        var process = new Process { StartInfo = start, EnableRaisingEvents = true };
        process.OutputDataReceived += (_, eventArgs) =>
        {
            if (!string.IsNullOrWhiteSpace(eventArgs.Data)) WriteLog(logPrefix, eventArgs.Data);
        };
        process.ErrorDataReceived += (_, eventArgs) =>
        {
            if (!string.IsNullOrWhiteSpace(eventArgs.Data)) WriteLog(logPrefix, eventArgs.Data);
        };
        if (!process.Start())
        {
            throw new InvalidOperationException($"تعذر تشغيل {Path.GetFileName(executable)}");
        }
        process.BeginOutputReadLine();
        process.BeginErrorReadLine();
        WriteLog("manager", $"Started {Path.GetFileName(executable)} (PID {process.Id})");
        return process;
    }

    private async Task StopOwnedProcessesAsync(string? postgresBinDir)
    {
        await StopProcessAsync(_backend);
        _backend = null;
        await StopPersistedBackendAsync();

        if (!string.IsNullOrWhiteSpace(postgresBinDir))
        {
            var pgCtl = Path.Combine(postgresBinDir, "pg_ctl.exe");
            if (File.Exists(pgCtl) && Directory.Exists(PostgresDataDir))
            {
                var start = new ProcessStartInfo
                {
                    FileName = pgCtl,
                    WorkingDirectory = postgresBinDir,
                    UseShellExecute = false,
                    CreateNoWindow = true,
                };
                foreach (var value in new[] { "stop", "-D", PostgresDataDir, "-m", "fast", "-w", "-t", "20" })
                {
                    start.ArgumentList.Add(value);
                }
                using var stopper = Process.Start(start);
                if (stopper is not null)
                {
                    using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(25));
                    try { await stopper.WaitForExitAsync(timeout.Token); }
                    catch (OperationCanceledException) { }
                }
            }
        }

        await StopProcessAsync(_postgres);
        _postgres = null;
    }

    private async Task StopPersistedBackendAsync()
    {
        if (!File.Exists(BackendPidPath)) return;
        try
        {
            var raw = await File.ReadAllTextAsync(BackendPidPath);
            if (!int.TryParse(raw.Trim(), out var pid)) return;
            using var process = Process.GetProcessById(pid);
            if (process.ProcessName.Contains("ChurchMembership.SyncServer", StringComparison.OrdinalIgnoreCase))
            {
                process.Kill(entireProcessTree: true);
                await process.WaitForExitAsync();
            }
        }
        catch { }
        finally
        {
            try { File.Delete(BackendPidPath); } catch { }
        }
    }

    private static async Task StopProcessAsync(Process? process)
    {
        if (process is null || process.HasExited) return;
        try
        {
            process.Kill(entireProcessTree: true);
            await process.WaitForExitAsync();
        }
        catch { }
    }

    private async Task<bool> WaitForHealthAsync(Process process, TimeSpan timeout)
    {
        var deadline = DateTime.UtcNow + timeout;
        while (DateTime.UtcNow < deadline)
        {
            if (process.HasExited) return false;
            if (await IsHealthyAsync()) return true;
            await Task.Delay(500);
        }
        return false;
    }

    private static async Task<bool> IsPortOpenAsync(int port)
    {
        try
        {
            using var client = new TcpClient();
            using var attempt = new CancellationTokenSource(TimeSpan.FromMilliseconds(400));
            await client.ConnectAsync(IPAddress.Loopback, port, attempt.Token);
            return true;
        }
        catch
        {
            return false;
        }
    }

    private async Task WaitForPostgresAsync(string postgresBinDir, TimeSpan timeout)
    {
        var deadline = DateTime.UtcNow + timeout;
        while (DateTime.UtcNow < deadline)
        {
            if (_postgres?.HasExited == true)
                throw new InvalidOperationException($"توقف PostgreSQL (ExitCode={_postgres.ExitCode}). راجع سجل مدير السيرفر.");
            var start = new ProcessStartInfo(Path.Combine(postgresBinDir, "pg_isready.exe"))
            {
                UseShellExecute = false, CreateNoWindow = true,
                RedirectStandardOutput = true, RedirectStandardError = true,
            };
            foreach (var arg in new[] { "-h", "127.0.0.1", "-p", _databasePort.ToString(), "-U", "postgres", "-t", "2", "-q" })
                start.ArgumentList.Add(arg);
            using var probe = Process.Start(start)
                ?? throw new InvalidOperationException("تعذر فحص جاهزية PostgreSQL.");
            await probe.WaitForExitAsync();
            if (probe.ExitCode == 0) return;
            await Task.Delay(1000);
        }
        throw new InvalidOperationException("لم تجهز قاعدة البيانات PostgreSQL خلال ثلاث دقائق. راجع سجل مدير السيرفر.");
    }

    private void RemoveStalePostmasterPid()
    {
        var pidFile = Path.Combine(PostgresDataDir, "postmaster.pid");
        if (!File.Exists(pidFile)) return;
        try
        {
            File.Delete(pidFile);
            WriteLog("manager", "Removed stale postmaster.pid");
        }
        catch (Exception ex)
        {
            WriteLog("manager", $"Could not delete postmaster.pid: {ex.Message}");
        }
    }

    private async void WatchdogTick(object? _)
    {
        if (!_desiredRunning || _disposed) return;
        if (_operationLock.CurrentCount == 0) return;

        try
        {
            if (!await IsHealthyAsync())
            {
                WriteLog("watchdog", "Server health check failed. Attempting recovery...");
                await StartAsync(recovering: true);
            }
        }
        catch (Exception ex)
        {
            WriteLog("watchdog", $"Watchdog error: {ex.Message}");
        }
    }

    private static IEnumerable<string> GetLanAddresses()
    {
        // Prefer a physical LAN interface with a gateway over VPN/host-only adapters.
        return NetworkInterface.GetAllNetworkInterfaces()
            .Where(item => item.OperationalStatus == OperationalStatus.Up
                && item.NetworkInterfaceType != NetworkInterfaceType.Loopback)
            .OrderBy(item => item.GetIPProperties().GatewayAddresses.Any(g =>
                g.Address.AddressFamily == AddressFamily.InterNetwork &&
                !g.Address.Equals(IPAddress.Any)) ? 0 : 1)
            .ThenBy(item => item.NetworkInterfaceType is NetworkInterfaceType.Ethernet
                or NetworkInterfaceType.Wireless80211 ? 0 : 1)
            .SelectMany(item => item.GetIPProperties().UnicastAddresses)
            .Where(item => item.Address.AddressFamily == AddressFamily.InterNetwork
                && !IPAddress.IsLoopback(item.Address)
                && !item.Address.ToString().StartsWith("169.254.", StringComparison.Ordinal))
            .Select(item => item.Address.ToString())
            .Distinct();
    }

    private void Publish(ServerState state, string message)
    {
        WriteLog("manager", $"[{state}] {message}");
        StatusChanged?.Invoke(this, new ServerStatusEventArgs(state, message));
    }

    public void WriteLog(string source, string line)
    {
        var formatted = $"[{DateTime.Now:yyyy-MM-dd HH:mm:ss}] [{source}] {line}";
        lock (_logLock)
        {
            try
            {
                File.AppendAllText(ManagerLogPath, formatted + Environment.NewLine, new UTF8Encoding(false));
            }
            catch { }
        }
        LogReceived?.Invoke(this, formatted);
    }

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;
        _watchdog.Dispose();
        _http.Dispose();
        _operationLock.Dispose();
    }
}
