using Microsoft.AspNetCore.SignalR;

namespace AbonaFlemoon.SyncServer.Hubs;

public class SyncHub : Hub
{
    private readonly ILogger<SyncHub> _logger;

    public SyncHub(ILogger<SyncHub> logger)
    {
        _logger = logger;
    }

    public override Task OnConnectedAsync()
    {
        _logger.LogInformation("Client connected to SyncHub: {ConnectionId}", Context.ConnectionId);
        return base.OnConnectedAsync();
    }

    public override Task OnDisconnectedAsync(Exception? exception)
    {
        _logger.LogInformation("Client disconnected from SyncHub: {ConnectionId}", Context.ConnectionId);
        return base.OnDisconnectedAsync(exception);
    }

    public Task Ping() => Clients.Caller.SendAsync("Pong", DateTime.UtcNow);
}
