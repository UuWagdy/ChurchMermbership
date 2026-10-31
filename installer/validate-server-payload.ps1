[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$BackendRoot,
    [Parameter(Mandatory = $true)][string]$ManagerRoot,
    [Parameter(Mandatory = $true)][string]$PostgresRoot
)
$ErrorActionPreference = 'Stop'

function Assert-SelfContainedPayload($Root, $Name, $Framework) {
    foreach ($file in @("$Name.exe", "$Name.dll", "$Name.deps.json", "$Name.runtimeconfig.json",
        'coreclr.dll', 'hostfxr.dll', 'hostpolicy.dll', 'System.Private.CoreLib.dll', $Framework)) {
        if (-not (Test-Path -LiteralPath (Join-Path $Root $file) -PathType Leaf)) {
            throw "Incomplete offline server payload: $Root\$file. Publish with --self-contained true."
        }
    }
    $config = Get-Content -LiteralPath (Join-Path $Root "$Name.runtimeconfig.json") -Raw | ConvertFrom-Json
    if ($config.runtimeOptions.framework -or $config.runtimeOptions.frameworks -or
        -not $config.runtimeOptions.includedFrameworks) {
        throw "$Name depends on a machine-wide .NET runtime. Publish with --self-contained true."
    }
}

Assert-SelfContainedPayload $BackendRoot 'ChurchMembership.SyncServer' 'Microsoft.AspNetCore.dll'
Assert-SelfContainedPayload $ManagerRoot 'ChurchMembershipServerManager' 'System.Windows.Forms.dll'
foreach ($file in @('bin\postgres.exe', 'bin\initdb.exe', 'bin\pg_ctl.exe', 'bin\pg_isready.exe',
    'bin\psql.exe', 'bin\createdb.exe', 'bin\pg_dump.exe', 'bin\pg_restore.exe', 'share\postgres.bki')) {
    if (-not (Test-Path -LiteralPath (Join-Path $PostgresRoot $file) -PathType Leaf)) {
        throw "Incomplete portable PostgreSQL payload: $PostgresRoot\$file"
    }
}
Write-Host 'Offline server payload verified (.NET + ASP.NET + Windows Desktop + PostgreSQL).'
