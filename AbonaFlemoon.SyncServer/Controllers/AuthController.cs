using AbonaFlemoon.SyncServer.Services;
using Microsoft.AspNetCore.Mvc;

namespace AbonaFlemoon.SyncServer.Controllers;

[ApiController]
[Route("api/auth")]
public class AuthController : ControllerBase
{
    private readonly StorageService _storageService;

    public AuthController(StorageService storageService)
    {
        _storageService = storageService;
    }

    [HttpGet("ping")]
    public async Task<IActionResult> Ping()
    {
        var dbHealthy = await _storageService.CheckDatabaseHealthAsync();
        if (!dbHealthy)
        {
            return StatusCode(503, new
            {
                status = "unhealthy",
                engine = "PostgreSQL",
                serverTime = DateTime.UtcNow
            });
        }

        return Ok(new
        {
            status = "ok",
            engine = "PostgreSQL",
            app = "ChurchMembership.SyncServer",
            serverTime = DateTime.UtcNow
        });
    }
}
