using System.Threading;

namespace AbonaFlemoonServerManager;

internal static class Program
{
    private const string MutexName = "AbonaFlemoon_ServerManager_5060_v1";
    public const string ShowWindowEventName = "AbonaFlemoon_ServerManager_ShowWindow_v1";

    [STAThread]
    private static void Main(string[] args)
    {
        var onlyTunnels = args.Any(value =>
            value.Equals("--tunnels", StringComparison.OrdinalIgnoreCase));
        if (onlyTunnels)
        {
            ApplicationConfiguration.Initialize();
            var root = ResolveInstallRoot(args);
            using var serverSup = new ServerSupervisor(root);
            using var tunnelSup = new TunnelSupervisor(root);
            using var form = new TunnelManagerForm(tunnelSup, serverSup);
            Application.Run(form);
            return;
        }

        var background = args.Any(value =>
            value.Equals("--background", StringComparison.OrdinalIgnoreCase));

        using var mutex = new Mutex(true, MutexName, out var isFirstInstance);
        if (!isFirstInstance)
        {
            if (!background)
            {
                try
                {
                    using var showEvent = EventWaitHandle.OpenExisting(ShowWindowEventName);
                    showEvent.Set();
                }
                catch
                {
                    MessageBox.Show(
                        "مدير سيرفر Church Membership - العضوية الكنسية يعمل بالفعل بجانب الساعة.",
                        "مدير سيرفر العضوية الكنسية",
                        MessageBoxButtons.OK,
                        MessageBoxIcon.Information);
                }
            }
            return;
        }

        ApplicationConfiguration.Initialize();
        var installRoot = ResolveInstallRoot(args);
        using var supervisor = new ServerSupervisor(installRoot);
        using var window = new MainForm(supervisor, background);
        Application.Run(window);
    }

    private static string ResolveInstallRoot(string[] args)
    {
        for (var index = 0; index < args.Length - 1; index++)
        {
            if (args[index].Equals("--install-root", StringComparison.OrdinalIgnoreCase))
            {
                return Path.GetFullPath(args[index + 1]);
            }
        }

        var executableDirectory = AppContext.BaseDirectory.TrimEnd(Path.DirectorySeparatorChar);
        if (Directory.Exists(Path.Combine(executableDirectory, "Server")) ||
            Directory.Exists(Path.Combine(executableDirectory, "server")))
        {
            return executableDirectory;
        }

        var parent = Directory.GetParent(executableDirectory)?.FullName;
        if (parent is not null && (Directory.Exists(Path.Combine(parent, "Server")) || Directory.Exists(Path.Combine(parent, "server"))))
        {
            return parent;
        }

        // Check dev workspace root
        var current = new DirectoryInfo(executableDirectory);
        for (int i = 0; i < 5 && current is not null; i++)
        {
            if (Directory.Exists(Path.Combine(current.FullName, "AbonaFlemoon.SyncServer")) ||
                File.Exists(Path.Combine(current.FullName, "pubspec.yaml")))
            {
                return current.FullName;
            }
            current = current.Parent;
        }

        return executableDirectory;
    }
}
