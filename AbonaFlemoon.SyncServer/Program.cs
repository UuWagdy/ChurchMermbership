using System.IO.Compression;
using AbonaFlemoon.SyncServer.Hubs;
using AbonaFlemoon.SyncServer.Services;
using Microsoft.AspNetCore.ResponseCompression;

var builder = WebApplication.CreateBuilder(args);

var port = builder.Configuration.GetValue<int?>("PORT") ?? 5060;
if (port is < 1 or > 65535) throw new InvalidOperationException("Invalid API port.");
builder.WebHost.UseUrls(builder.Configuration.GetValue<bool>("BindLocalOnly")
    ? $"http://127.0.0.1:{port}" : $"http://0.0.0.0:{port}");

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

builder.Services.AddSignalR(options =>
{
    options.EnableDetailedErrors = true;
    options.KeepAliveInterval = TimeSpan.FromSeconds(15);
    options.ClientTimeoutInterval = TimeSpan.FromSeconds(45);
});

builder.Services.AddResponseCompression(options =>
{
    options.EnableForHttps = true;
    options.Providers.Add<BrotliCompressionProvider>();
    options.Providers.Add<GzipCompressionProvider>();
    options.MimeTypes = ResponseCompressionDefaults.MimeTypes.Concat(new[] { "application/json" });
});
builder.Services.Configure<BrotliCompressionProviderOptions>(opts => opts.Level = CompressionLevel.Fastest);
builder.Services.Configure<GzipCompressionProviderOptions>(opts => opts.Level = CompressionLevel.Fastest);

builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
    {
        policy.SetIsOriginAllowed(_ => true)
              .AllowAnyHeader()
              .AllowAnyMethod()
              .AllowCredentials();
    });
});

builder.Services.AddSingleton<StorageService>();
builder.Services.AddSingleton(sp => new DatabaseBackups.NativeBackupService(
    builder.Configuration.GetConnectionString("Postgres")!, "ChurchMembership",
    sp.GetRequiredService<ILogger<DatabaseBackups.NativeBackupService>>()));
builder.Services.AddHostedService(sp => sp.GetRequiredService<DatabaseBackups.NativeBackupService>());

var app = builder.Build();

using (var scope = app.Services.CreateScope())
{
    var logger = scope.ServiceProvider.GetRequiredService<ILoggerFactory>().CreateLogger("Startup");
    var connStr = builder.Configuration.GetConnectionString("Postgres")!;
    var initialSqlitePath = builder.Configuration["SqliteSeed:InitialDbPath"];
    await PostgresSchemaInitializer.EnsureDatabaseAndSchemaAsync(connStr, initialSqlitePath, logger);
}

app.UseResponseCompression();
app.UseCors("AllowAll");
app.UseSwagger();
app.UseSwaggerUI();

app.MapControllers();
app.MapGet("/health", () => Results.Ok(new
{
    status = "ok",
    service = "ChurchMembership.SyncServer",
    database = "PostgreSQL",
    signalR = true,
    port,
    utc = DateTime.UtcNow
}));
app.MapHub<SyncHub>("/hubs/sync");

app.Run();
