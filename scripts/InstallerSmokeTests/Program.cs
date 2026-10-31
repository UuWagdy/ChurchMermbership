using System.Net;
using System.Net.Sockets;
using System.Reflection;

// Exercises the packaged EXEs, never dotnet <backend.dll> or an installed database.
var root = Path.GetFullPath(args[0]);
int FreePort()
{
    var listener = new TcpListener(IPAddress.Loopback, 0);
    listener.Start();
    var port = ((IPEndPoint)listener.LocalEndpoint).Port;
    listener.Stop();
    return port;
}
var apiPort = FreePort();
var dbPort = FreePort();
while (apiPort == dbPort) dbPort = FreePort();
Environment.SetEnvironmentVariable("DOTNET_ROOT", Path.Combine(root, "no-global-dotnet"));
Environment.SetEnvironmentVariable("DOTNET_ROOT_X64", Path.Combine(root, "no-global-dotnet"));
Environment.SetEnvironmentVariable("DOTNET_MULTILEVEL_LOOKUP", "0");
Environment.SetEnvironmentVariable("HTTP_PROXY", "http://127.0.0.1:1");
Environment.SetEnvironmentVariable("ALL_PROXY", "http://127.0.0.1:1");
Environment.SetEnvironmentVariable("NO_PROXY", "");
Environment.SetEnvironmentVariable("BindLocalOnly", "true");
var type = Assembly.GetExecutingAssembly().GetTypes().Single(t => t.Name == "ServerSupervisor");
using var supervisor = (IDisposable)Activator.CreateInstance(type, root, apiPort, dbPort, Path.Combine(root, "test-data"))!;
async Task Call(string method, params object[] values) =>
    await (Task)type.GetMethod(method)!.Invoke(supervisor, values)!;
async Task CheckHealthy()
{
    if (!await (Task<bool>)type.GetMethod("IsHealthyAsync")!.Invoke(supervisor, null)!)
        throw new Exception("Packaged server failed health check; inspect " + root);
}
try
{
    await Call("StartAsync", false);
    await CheckHealthy();
    Console.WriteLine("PASS: first run, actual PostgreSQL readiness, schema creation, private .NET runtime, proxy bypass.");
    await Call("RestartAsync");
    await CheckHealthy();
    Console.WriteLine("PASS: restart preserves and reuses initialized cluster.");
}
finally { await Call("StopAsync"); }
Console.WriteLine($"PASS: clean stop; isolated root={root}; ports={apiPort},{dbPort}");
