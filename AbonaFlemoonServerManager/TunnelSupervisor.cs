using System.Diagnostics;
using System.IO.Compression;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace AbonaFlemoonServerManager;

internal enum TunnelMode
{
    None,
    CloudflareQuick,
    CloudflareStable,
    Ngrok,
}

internal sealed class TunnelConfig
{
    public TunnelMode Mode { get; set; } = TunnelMode.CloudflareQuick;
    public string NgrokToken { get; set; } = string.Empty;
    public string NgrokDomain { get; set; } = string.Empty;
    public string CloudflareToken { get; set; } = string.Empty;
}

internal sealed class TunnelSupervisor : IDisposable
{
    private const int ApiPort = ServerSupervisor.ApiPort;
    private readonly string _installRoot;
    private readonly string _configPath;
    private readonly object _lock = new();
    private Process? _tunnelProcess;
    private bool _disposed;

    public TunnelSupervisor(string installRoot)
    {
        _installRoot = Path.GetFullPath(installRoot).TrimEnd(Path.DirectorySeparatorChar);
        var serverData = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "ChurchMembership_ServerData");
        var legacyData = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "AbonaFlemoon_ServerData");
        if (!File.Exists(Path.Combine(serverData, "pgdata", "PG_VERSION")) && File.Exists(Path.Combine(legacyData, "pgdata", "PG_VERSION"))) serverData = legacyData;
        Directory.CreateDirectory(serverData);
        _configPath = Path.Combine(serverData, "tunnel_config.json");
        Config = LoadConfig();
    }

    public TunnelConfig Config { get; }
    public string? ActiveUrl { get; private set; }
    public TunnelMode CurrentRunningMode { get; private set; } = TunnelMode.None;
    public bool IsRunning => _tunnelProcess != null && !_tunnelProcess.HasExited;

    public event EventHandler<string>? UrlDetected;
    public event EventHandler<string>? LogReceived;
    public event EventHandler<bool>? StatusChanged;

    public static string? FindExecutable(string name, string? installRoot = null)
    {
        var exeName = name.EndsWith(".exe", StringComparison.OrdinalIgnoreCase) ? name : $"{name}.exe";

        var candidates = new List<string>
        {
            Path.Combine(AppContext.BaseDirectory, exeName),
            Path.Combine(AppContext.BaseDirectory, "tools", exeName),
            Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "tools", exeName),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "AbonaFlemoon", "tools", exeName),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "ChurchMembership_ServerData", "tools", exeName),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "SundaySchool", "tools", exeName),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "DrSales", "tools", exeName),
            @"E:\Final\petros_pols_flutter\SundaySchoolServerManager\tools\" + exeName,
            @"E:\POWER\Offline_First_Sync\sales_flutter_app\DrSalesServerManager\tools\" + exeName,
        };

        if (!string.IsNullOrWhiteSpace(installRoot))
        {
            candidates.Add(Path.Combine(installRoot, "tools", exeName));
            candidates.Add(Path.Combine(installRoot, "ServerManager", "tools", exeName));
            candidates.Add(Path.Combine(installRoot, exeName));
        }

        if (name.StartsWith("cloudflare", StringComparison.OrdinalIgnoreCase))
        {
            candidates.Add(@"C:\Program Files (x86)\cloudflared\cloudflared.exe");
            candidates.Add(@"C:\Program Files\cloudflared\cloudflared.exe");
        }

        foreach (var path in candidates)
        {
            try
            {
                var full = Path.GetFullPath(path);
                if (File.Exists(full)) return full;
            }
            catch { }
        }

        var pathEnv = Environment.GetEnvironmentVariable("PATH") ?? string.Empty;
        foreach (var dir in pathEnv.Split(Path.PathSeparator, StringSplitOptions.RemoveEmptyEntries))
        {
            try
            {
                var candidate = Path.Combine(dir.Trim(), exeName);
                if (File.Exists(candidate)) return candidate;
            }
            catch { }
        }

        return null;
    }

    public async Task<string> EnsureToolAsync(string toolName)
    {
        var existing = FindExecutable(toolName, _installRoot);
        if (existing != null) return existing;

        var isCloudflare = toolName.StartsWith("cloudflare", StringComparison.OrdinalIgnoreCase);
        var isNgrok = toolName.StartsWith("ngrok", StringComparison.OrdinalIgnoreCase);

        var targetDir = GetToolsDirectory();
        var targetExe = Path.Combine(targetDir, isCloudflare ? "cloudflared.exe" : "ngrok.exe");

        if (File.Exists(targetExe)) return targetExe;

        LogReceived?.Invoke(this, $"[التحميل التلقائي] الأداة {toolName} غير موجودة. جاري التنزيل التلقائي الآن...");

        using var client = new HttpClient();
        client.Timeout = TimeSpan.FromMinutes(5);
        client.DefaultRequestHeaders.UserAgent.ParseAdd("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AbonaFlemoonServerManager");

        if (isCloudflare)
        {
            const string cfUrl = "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe";
            LogReceived?.Invoke(this, "[التحميل التلقائي] جاري تنزيل cloudflared.exe من المصدر الرسمي...");

            var tempFile = Path.Combine(targetDir, "cloudflared.tmp");
            await DownloadFileWithProgressAsync(client, cfUrl, tempFile);

            if (File.Exists(targetExe)) File.Delete(targetExe);
            File.Move(tempFile, targetExe, true);
            LogReceived?.Invoke(this, $"[التحميل التلقائي] تم تثبيت الأداة بنجاح: {targetExe}");
            return targetExe;
        }
        else if (isNgrok)
        {
            const string ngrokZipUrl = "https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-windows-amd64.zip";
            LogReceived?.Invoke(this, "[التحميل التلقائي] جاري تنزيل حزمة ngrok.zip وفك ضغطها...");

            var zipPath = Path.Combine(targetDir, "ngrok.zip");
            await DownloadFileWithProgressAsync(client, ngrokZipUrl, zipPath);

            try
            {
                using (var archive = ZipFile.OpenRead(zipPath))
                {
                    var entry = archive.Entries.FirstOrDefault(e => e.Name.Equals("ngrok.exe", StringComparison.OrdinalIgnoreCase));
                    if (entry != null)
                    {
                        if (File.Exists(targetExe)) File.Delete(targetExe);
                        entry.ExtractToFile(targetExe, true);
                    }
                    else
                    {
                        throw new FileNotFoundException("لم يتم العثور على ngrok.exe داخل الحزمة المنزلة.");
                    }
                }
            }
            finally
            {
                if (File.Exists(zipPath))
                {
                    try { File.Delete(zipPath); } catch { }
                }
            }

            LogReceived?.Invoke(this, $"[التحميل التلقائي] تم تثبيت الأداة بنجاح: {targetExe}");
            return targetExe;
        }

        throw new FileNotFoundException($"لا توجد طريقة تحميل تلقائية معروفة للأداة {toolName}");
    }

    private string GetToolsDirectory()
    {
        var candidates = new List<string>
        {
            Path.Combine(AppContext.BaseDirectory, "tools"),
            Path.Combine(_installRoot, "ServerManager", "tools"),
            Path.Combine(_installRoot, "tools"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "ChurchMembership_ServerData", "tools"),
        };

        foreach (var dir in candidates)
        {
            try
            {
                Directory.CreateDirectory(dir);
                return dir;
            }
            catch { }
        }

        return AppContext.BaseDirectory;
    }

    private async Task DownloadFileWithProgressAsync(HttpClient client, string url, string destinationPath)
    {
        using var response = await client.GetAsync(url, HttpCompletionOption.ResponseHeadersRead);
        response.EnsureSuccessStatusCode();

        var totalBytes = response.Content.Headers.ContentLength ?? -1L;
        await using var contentStream = await response.Content.ReadAsStreamAsync();
        await using var fileStream = new FileStream(destinationPath, FileMode.Create, FileAccess.Write, FileShare.None, 81920, true);

        var buffer = new byte[81920];
        long totalRead = 0;
        int read;
        var lastReportTime = DateTime.UtcNow;

        while ((read = await contentStream.ReadAsync(buffer, 0, buffer.Length)) > 0)
        {
            await fileStream.WriteAsync(buffer, 0, read);
            totalRead += read;

            if ((DateTime.UtcNow - lastReportTime).TotalMilliseconds >= 800)
            {
                lastReportTime = DateTime.UtcNow;
                if (totalBytes > 0)
                {
                    var percent = (int)((totalRead * 100) / totalBytes);
                    var mb = totalRead / (1024.0 * 1024.0);
                    var totalMb = totalBytes / (1024.0 * 1024.0);
                    LogReceived?.Invoke(this, $"[التحميل التلقائي] تقدم التنزيل: {percent}% ({mb:F1}MB / {totalMb:F1}MB)...");
                }
                else
                {
                    var mb = totalRead / (1024.0 * 1024.0);
                    LogReceived?.Invoke(this, $"[التحميل التلقائي] تم تحميل {mb:F1}MB...");
                }
            }
        }
    }

    public async Task StartCloudflareQuickAsync()
    {
        StopTunnel();
        var exe = await EnsureToolAsync("cloudflared");

        CurrentRunningMode = TunnelMode.CloudflareQuick;
        ActiveUrl = null;
        StatusChanged?.Invoke(this, true);
        LogReceived?.Invoke(this, "[Cloudflare Quick] جاري طلب نفق سريع ومجاني مؤقت...");

        var startInfo = new ProcessStartInfo
        {
            FileName = exe,
            Arguments = $"tunnel --url http://127.0.0.1:{ApiPort}",
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true,
            StandardOutputEncoding = Encoding.UTF8,
            StandardErrorEncoding = Encoding.UTF8,
        };

        _tunnelProcess = new Process { StartInfo = startInfo, EnableRaisingEvents = true };

        _tunnelProcess.OutputDataReceived += (_, e) => HandleProcessOutput(e.Data);
        _tunnelProcess.ErrorDataReceived += (_, e) => HandleProcessOutput(e.Data);
        _tunnelProcess.Exited += (_, _) =>
        {
            CurrentRunningMode = TunnelMode.None;
            ActiveUrl = null;
            StatusChanged?.Invoke(this, false);
            LogReceived?.Invoke(this, "[Cloudflare Quick] تم إغلاق النفق.");
        };

        _tunnelProcess.Start();
        _tunnelProcess.BeginOutputReadLine();
        _tunnelProcess.BeginErrorReadLine();

        await Task.CompletedTask;
    }

    public async Task StartNgrokAsync(string domain, string? token)
    {
        StopTunnel();
        var exe = await EnsureToolAsync("ngrok");

        if (!string.IsNullOrWhiteSpace(token))
        {
            LogReceived?.Invoke(this, "[Ngrok] جاري حفظ رمز التفعيل (Auth Token)...");
            var tokenProcess = Process.Start(new ProcessStartInfo
            {
                FileName = exe,
                Arguments = $"config add-authtoken {token.Trim()}",
                UseShellExecute = false,
                CreateNoWindow = true,
            });
            if (tokenProcess != null) await tokenProcess.WaitForExitAsync();
        }

        CurrentRunningMode = TunnelMode.Ngrok;
        var cleanDomain = domain.Trim().Replace("https://", "").Replace("http://", "").TrimEnd('/');
        ActiveUrl = string.IsNullOrWhiteSpace(cleanDomain) ? null : $"https://{cleanDomain}";
        StatusChanged?.Invoke(this, true);
        LogReceived?.Invoke(this, $"[Ngrok] جاري تشغيل النفق {(ActiveUrl != null ? $"للدومين: {ActiveUrl}" : "")}...");

        var args = string.IsNullOrWhiteSpace(cleanDomain)
            ? $"http http://127.0.0.1:{ApiPort} --log stdout"
            : $"http http://127.0.0.1:{ApiPort} --url https://{cleanDomain} --log stdout";

        var startInfo = new ProcessStartInfo
        {
            FileName = exe,
            Arguments = args,
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true,
            StandardOutputEncoding = Encoding.UTF8,
            StandardErrorEncoding = Encoding.UTF8,
        };

        _tunnelProcess = new Process { StartInfo = startInfo, EnableRaisingEvents = true };

        _tunnelProcess.OutputDataReceived += (_, e) => HandleProcessOutput(e.Data);
        _tunnelProcess.ErrorDataReceived += (_, e) => HandleProcessOutput(e.Data);
        _tunnelProcess.Exited += (_, _) =>
        {
            CurrentRunningMode = TunnelMode.None;
            ActiveUrl = null;
            StatusChanged?.Invoke(this, false);
            LogReceived?.Invoke(this, "[Ngrok] تم إغلاق النفق.");
        };

        _tunnelProcess.Start();
        _tunnelProcess.BeginOutputReadLine();
        _tunnelProcess.BeginErrorReadLine();

        if (ActiveUrl != null)
        {
            UrlDetected?.Invoke(this, ActiveUrl);
        }
    }

    public async Task<string> InstallCloudflareServiceAsync(string token)
    {
        var exe = await EnsureToolAsync("cloudflared");

        LogReceived?.Invoke(this, "[Cloudflare Service] جاري تثبيت خدمة الويندوز الدائمة...");
        var process = Process.Start(new ProcessStartInfo
        {
            FileName = exe,
            Arguments = $"service install {token.Trim()}",
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true,
        });

        if (process == null) throw new InvalidOperationException("تعذر تشغيل أمر تثبيت الخدمة.");
        var output = await process.StandardOutput.ReadToEndAsync();
        var error = await process.StandardError.ReadToEndAsync();
        await process.WaitForExitAsync();

        var message = string.IsNullOrWhiteSpace(output) ? error : output;
        LogReceived?.Invoke(this, $"[Cloudflare Service] {message}");
        return message;
    }

    public async Task<string> UninstallCloudflareServiceAsync()
    {
        var exe = await EnsureToolAsync("cloudflared");

        LogReceived?.Invoke(this, "[Cloudflare Service] جاري إلغاء تثبيت خدمة الويندوز...");
        var process = Process.Start(new ProcessStartInfo
        {
            FileName = exe,
            Arguments = "service uninstall",
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true,
        });

        if (process == null) throw new InvalidOperationException("تعذر تشغيل أمر إزالة الخدمة.");
        var output = await process.StandardOutput.ReadToEndAsync();
        var error = await process.StandardError.ReadToEndAsync();
        await process.WaitForExitAsync();

        var message = string.IsNullOrWhiteSpace(output) ? error : output;
        LogReceived?.Invoke(this, $"[Cloudflare Service] {message}");
        return message;
    }

    public void StopTunnel()
    {
        lock (_lock)
        {
            if (_tunnelProcess != null && !_tunnelProcess.HasExited)
            {
                try
                {
                    _tunnelProcess.Kill(true);
                    _tunnelProcess.Dispose();
                }
                catch { }
            }
            _tunnelProcess = null;
            CurrentRunningMode = TunnelMode.None;
            ActiveUrl = null;
            StatusChanged?.Invoke(this, false);
        }
    }

    private void HandleProcessOutput(string? data)
    {
        if (string.IsNullOrWhiteSpace(data)) return;

        LogReceived?.Invoke(this, data);

        if (CurrentRunningMode == TunnelMode.CloudflareQuick && ActiveUrl == null)
        {
            var match = Regex.Match(data, @"https://[a-zA-Z0-9-]+\.trycloudflare\.com");
            if (match.Success)
            {
                ActiveUrl = match.Value;
                UrlDetected?.Invoke(this, ActiveUrl);
                LogReceived?.Invoke(this, $"[Cloudflare Quick] تم إنشاء الرابط السريع بنجاح: {ActiveUrl}");
            }
        }

        if (CurrentRunningMode == TunnelMode.Ngrok && ActiveUrl == null)
        {
            var match = Regex.Match(data, @"url=(https://[a-zA-Z0-9.-]+\.ngrok(?:-free)?\.(?:app|dev))");
            if (match.Success)
            {
                ActiveUrl = match.Groups[1].Value;
                UrlDetected?.Invoke(this, ActiveUrl);
                LogReceived?.Invoke(this, $"[Ngrok] تم تشغيل الرابط بنجاح: {ActiveUrl}");
            }
        }
    }

    public void SaveConfig()
    {
        try
        {
            var json = JsonSerializer.Serialize(Config, new JsonSerializerOptions { WriteIndented = true });
            File.WriteAllText(_configPath, json);
        }
        catch (Exception ex)
        {
            LogReceived?.Invoke(this, $"[Config Error] تعذر حفظ إعدادات النفق: {ex.Message}");
        }
    }

    private TunnelConfig LoadConfig()
    {
        try
        {
            if (File.Exists(_configPath))
            {
                var json = File.ReadAllText(_configPath);
                var cfg = JsonSerializer.Deserialize<TunnelConfig>(json);
                if (cfg != null) return cfg;
            }
        }
        catch { }
        return new TunnelConfig();
    }

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;
        StopTunnel();
    }
}
