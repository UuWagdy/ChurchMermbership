using AbonaFlemoon.SyncServer.Models;
using AbonaFlemoon.SyncServer.Services;
using Microsoft.AspNetCore.Mvc;

namespace AbonaFlemoon.SyncServer.Controllers;

[ApiController]
[Route("api/storage")]
public class StorageController : ControllerBase
{
    private readonly StorageService _storageService;
    private readonly ILogger<StorageController> _logger;

    public StorageController(StorageService storageService, ILogger<StorageController> logger)
    {
        _storageService = storageService;
        _logger = logger;
    }

    [HttpPost("query")]
    public async Task<IActionResult> Query([FromBody] SqlStatementRequest request)
    {
        try
        {
            var result = await _storageService.QueryAsync(request);
            return Ok(result);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Query failed for SQL: {Sql}", request.Sql);
            return BadRequest(new { error = ex.Message });
        }
    }

    [HttpPost("insert")]
    public async Task<IActionResult> Insert([FromBody] SqlStatementRequest request)
    {
        try
        {
            var result = await _storageService.InsertAsync(request);
            return Ok(result);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Insert failed for SQL: {Sql}", request.Sql);
            return BadRequest(new { error = ex.Message });
        }
    }

    [HttpPost("execute")]
    public async Task<IActionResult> Execute([FromBody] SqlStatementRequest request)
    {
        try
        {
            var result = await _storageService.ExecuteAsync(request);
            return Ok(result);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Execute failed for SQL: {Sql}", request.Sql);
            return BadRequest(new { error = ex.Message });
        }
    }

    [HttpPost("batch")]
    public async Task<IActionResult> Batch([FromBody] SqlBatchRequest request)
    {
        try
        {
            var result = await _storageService.ExecuteBatchAsync(request);
            return Ok(result);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Batch execution failed.");
            return BadRequest(new { error = ex.Message });
        }
    }

    [HttpPost("tx/begin")]
    public async Task<IActionResult> BeginTransaction()
    {
        try
        {
            var result = await _storageService.BeginTransactionAsync();
            return Ok(result);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "BeginTransaction failed.");
            return BadRequest(new { error = ex.Message });
        }
    }

    [HttpPost("tx/commit")]
    public async Task<IActionResult> CommitTransaction([FromBody] TxActionRequest request)
    {
        try
        {
            await _storageService.CommitTransactionAsync(request.TxId);
            return Ok(new { status = "committed" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "CommitTransaction failed for {TxId}", request.TxId);
            return BadRequest(new { error = ex.Message });
        }
    }

    [HttpPost("tx/rollback")]
    public async Task<IActionResult> RollbackTransaction([FromBody] TxActionRequest request)
    {
        try
        {
            await _storageService.RollbackTransactionAsync(request.TxId);
            return Ok(new { status = "rolled_back" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "RollbackTransaction failed for {TxId}", request.TxId);
            return BadRequest(new { error = ex.Message });
        }
    }

    [HttpGet("sqlite/export")]
    public async Task<IActionResult> ExportSqlite()
    {
        try
        {
            var bytes = await _storageService.ExportToSqliteBytesAsync();
            return File(bytes, "application/octet-stream", $"eakhow_elrab_backup_{DateTime.Now:yyyyMMdd_HHmm}.db");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "SQLite export failed.");
            return BadRequest(new { error = ex.Message });
        }
    }

    [HttpPost("sqlite/import")]
    [RequestSizeLimit(200_000_000)]
    public async Task<IActionResult> ImportSqlite()
    {
        try
        {
            byte[] sqliteBytes;
            if (Request.HasFormContentType && Request.Form.Files.Count > 0)
            {
                using var ms = new MemoryStream();
                await Request.Form.Files[0].CopyToAsync(ms);
                sqliteBytes = ms.ToArray();
            }
            else
            {
                using var ms = new MemoryStream();
                await Request.Body.CopyToAsync(ms);
                sqliteBytes = ms.ToArray();
            }

            if (sqliteBytes.Length < 100)
            {
                return BadRequest(new { error = "ملف قاعدة البيانات المرسل فارغ أو غير صالح." });
            }

            await _storageService.ImportFromSqliteBytesAsync(sqliteBytes);
            return Ok(new { status = "imported" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "SQLite import failed.");
            return BadRequest(new { error = ex.Message });
        }
    }
}
