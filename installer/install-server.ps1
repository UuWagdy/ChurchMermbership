[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$InstallRoot,
    [string]$InstallDir,
    [string]$DataRoot,
    [int]$ServerPort = 5060,
    [int]$ApiPort = 5060,
    [int]$PostgresPort = 5438,
    [int]$DatabasePort = 5438,
    [string]$DatabaseName = 'church_membership',
    [string]$InstallerVersion = '1.0.0',
    [switch]$StartNow,
    [switch]$Silent,
    [switch]$PrepareDatabaseOnly
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

if ([string]::IsNullOrWhiteSpace($InstallRoot)) {
    $InstallRoot = $InstallDir
}
if ([string]::IsNullOrWhiteSpace($InstallRoot)) {
    $InstallRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
}
$InstallRoot = [IO.Path]::GetFullPath($InstallRoot).TrimEnd('\', '/')

if ($ServerPort -ne 5060) { $ApiPort = $ServerPort }
if ($PostgresPort -ne 5438) { $DatabasePort = $PostgresPort }

if ([string]::IsNullOrWhiteSpace($DataRoot)) {
    $localAppData = [Environment]::GetFolderPath('LocalApplicationData')
    $DataRoot = Join-Path $localAppData 'ChurchMembership_ServerData'
    $legacyData = Join-Path $localAppData 'AbonaFlemoon_ServerData'
    if (-not (Test-Path -LiteralPath (Join-Path $DataRoot 'pgdata\PG_VERSION')) -and (Test-Path -LiteralPath (Join-Path $legacyData 'pgdata\PG_VERSION'))) { $DataRoot = $legacyData }
}
$DataRoot = [IO.Path]::GetFullPath($DataRoot).TrimEnd('\', '/')

$ServerRoot = Join-Path $InstallRoot 'Server'
$PostgresBin = Join-Path $ServerRoot 'postgresql\bin'
if (-not (Test-Path -LiteralPath $PostgresBin)) {
    $PostgresBin = Join-Path $InstallRoot 'pgsql\bin'
}
$PgCtl = Join-Path $PostgresBin 'pg_ctl.exe'
$InitDb = Join-Path $PostgresBin 'initdb.exe'
$Psql = Join-Path $PostgresBin 'psql.exe'
$CreateDb = Join-Path $PostgresBin 'createdb.exe'
$PgIsReady = Join-Path $PostgresBin 'pg_isready.exe'

$PostgresData = Join-Path $DataRoot 'pgdata'
$LogsRoot = Join-Path $DataRoot 'logs'
$InfoFile = Join-Path $InstallRoot 'SERVER_INFO.txt'
$ProgramDataInfoDir = Join-Path $env:ProgramData 'AbonaFlemoon'
$ProgramDataInfoFile = Join-Path $ProgramDataInfoDir 'SERVER_INFO.txt'

New-Item -ItemType Directory -Force -Path $DataRoot, $LogsRoot | Out-Null
if (-not $PrepareDatabaseOnly) { New-Item -ItemType Directory -Force -Path $ProgramDataInfoDir | Out-Null }
Start-Transcript -Path (Join-Path $LogsRoot 'install-server.log') -Append | Out-Null
try {
& (Join-Path $PSScriptRoot 'validate-server-payload.ps1') `
    -BackendRoot (Join-Path $ServerRoot 'backend') `
    -ManagerRoot (Join-Path $InstallRoot 'ServerManager') `
    -PostgresRoot (Split-Path -Parent $PostgresBin)

# Release this installation's old connections before renaming its database.
foreach ($processName in @('ChurchMembershipServerManager', 'ChurchMembership.SyncServer', 'AbonaFlemoonServerManager', 'AbonaFlemoon.SyncServer')) {
    Get-Process -Name $processName -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -and $_.Path.StartsWith($InstallRoot + '\', [StringComparison]::OrdinalIgnoreCase) } |
        Stop-Process -Force -ErrorAction SilentlyContinue
}

# 1. Initialize portable PostgreSQL cluster if present and not yet initialized
if (Test-Path -LiteralPath $InitDb -PathType Leaf) {
    if (-not (Test-Path -LiteralPath (Join-Path $PostgresData 'PG_VERSION') -PathType Leaf)) {
        New-Item -ItemType Directory -Force -Path $PostgresData | Out-Null
        & $InitDb -D $PostgresData -U postgres -E UTF8 --locale=C --auth=trust | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "initdb failed with exit code $LASTEXITCODE"
        }
        Add-Content -LiteralPath (Join-Path $PostgresData 'postgresql.conf') -Encoding UTF8 -Value @"

# Church Membership managed settings
listen_addresses = '127.0.0.1'
port = $DatabasePort
"@
    }

    # Start PostgreSQL briefly to ensure target database exists
    $bootstrapLog = Join-Path $LogsRoot 'postgres-bootstrap.log'
    $status = Start-Process -FilePath $PgCtl -ArgumentList "status -D `"$PostgresData`"" -WindowStyle Hidden -Wait -PassThru
    $startedForPreparation = $status.ExitCode -ne 0
    try {
        if ($startedForPreparation) {
            $proc = Start-Process -FilePath $PgCtl -ArgumentList "start -D `"$PostgresData`" -o `"-h 127.0.0.1 -p $DatabasePort`" -l `"$bootstrapLog`" -w -t 180" -WindowStyle Hidden -PassThru
            $proc.WaitForExit()
            if ($proc.ExitCode -ne 0) { throw "PostgreSQL startup failed (exit $($proc.ExitCode)). See $bootstrapLog" }
        }
        for ($i = 0; $i -lt 180; $i++) {
            & $PgIsReady -h 127.0.0.1 -p $DatabasePort -U postgres -d postgres -q
            if ($LASTEXITCODE -eq 0) { break }
            Start-Sleep -Seconds 1
        }
        if ($LASTEXITCODE -ne 0) { throw 'PostgreSQL did not become ready.' }
        $actualData = & $Psql -h 127.0.0.1 -p $DatabasePort -U postgres -d postgres -tAc 'SHOW data_directory'
        if ($LASTEXITCODE -ne 0 -or [IO.Path]::GetFullPath(($actualData | Out-String).Trim()).TrimEnd('\', '/') -ne $PostgresData) {
            throw 'The database port belongs to another PostgreSQL data directory. Check port configuration.'
        }

        $dbExists = & $Psql -h 127.0.0.1 -p $DatabasePort -U postgres -d postgres -v ON_ERROR_STOP=1 -tAc "SELECT 1 FROM pg_database WHERE datname='$DatabaseName'"
        if ($LASTEXITCODE -ne 0) { throw 'Could not check the membership database.' }
        if ([string]::IsNullOrWhiteSpace($dbExists) -and $DatabaseName -eq 'church_membership') {
            $legacyExists = & $Psql -h 127.0.0.1 -p $DatabasePort -U postgres -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='abona_flemoon'"
            if ($LASTEXITCODE -ne 0) { throw 'Could not check the legacy membership database.' }
            if (-not [string]::IsNullOrWhiteSpace($legacyExists)) {
                & $Psql -h 127.0.0.1 -p $DatabasePort -U postgres -d postgres -v ON_ERROR_STOP=1 -c 'ALTER DATABASE abona_flemoon RENAME TO church_membership' | Out-Null
                if ($LASTEXITCODE -ne 0) { throw 'Could not migrate the existing membership database.' }
                $dbExists = '1'
            }
        }
        if ([string]::IsNullOrWhiteSpace($dbExists)) {
            & $CreateDb -h 127.0.0.1 -p $DatabasePort -U postgres $DatabaseName | Out-Null
            if ($LASTEXITCODE -ne 0) { throw 'Could not create the membership database.' }
        }
    } finally {
        if ($startedForPreparation) {
            & $PgCtl stop -D $PostgresData -m fast -w -t 180 | Out-Null
            if ($LASTEXITCODE -ne 0) { throw 'Could not stop PostgreSQL after installation preparation.' }
        }
    }
}

# 2. Configure Windows Firewall rules for ports 5060 (API/SignalR) and 5435 (PostgreSQL)
if ($PrepareDatabaseOnly) { return }
& netsh.exe advfirewall firewall delete rule name='Church Membership Sync Server (5060)' 2>&1 | Out-Null
& netsh.exe advfirewall firewall add rule name='Church Membership Sync Server (5060)' dir=in action=allow protocol=TCP localport=$ApiPort profile=domain,private,public 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Could not configure the membership API firewall rule.' }

& netsh.exe advfirewall firewall delete rule name='Church Membership PostgreSQL (5438)' 2>&1 | Out-Null
& netsh.exe advfirewall firewall add rule name='Church Membership PostgreSQL (5438)' dir=in action=allow protocol=TCP localport=$DatabasePort profile=domain,private 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Could not configure the membership PostgreSQL firewall rule.' }

# 3. Discover LAN IPv4 and write SERVER_INFO.txt
$lanIp = ([Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() |
    Where-Object { $_.OperationalStatus -eq 'Up' -and $_.NetworkInterfaceType -ne 'Loopback' } |
    Sort-Object @{Expression={ if ($_.GetIPProperties().GatewayAddresses | Where-Object {
        $_.Address.AddressFamily -eq [Net.Sockets.AddressFamily]::InterNetwork -and
        -not $_.Address.Equals([Net.IPAddress]::Any) }) { 0 } else { 1 } }} |
    ForEach-Object { $_.GetIPProperties().UnicastAddresses.Address } |
    Where-Object { $_.AddressFamily -eq [Net.Sockets.AddressFamily]::InterNetwork -and -not [Net.IPAddress]::IsLoopback($_) } |
    Where-Object { -not $_.ToString().StartsWith('169.254.') } |
    ForEach-Object { $_.ToString() } |
    Select-Object -First 1)
if ([string]::IsNullOrWhiteSpace($lanIp)) { $lanIp = '127.0.0.1' }

$infoLines = @(
    "LOCAL_URL=http://127.0.0.1:$ApiPort"
    "LAN_URL=http://$($lanIp):$ApiPort"
    "SIGNALR_HUB=http://$($lanIp):$ApiPort/hubs/sync"
    "POSTGRES_PORT=$DatabasePort"
    "DATABASE_NAME=$DatabaseName"
    "UPDATED_AT=$(Get-Date -Format o)"
)
[IO.File]::WriteAllLines($InfoFile, $infoLines, [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllLines($ProgramDataInfoFile, $infoLines, [Text.UTF8Encoding]::new($false))

# 4. Register Manager to auto-start with Windows in HKCU\Run
$managerExe = Join-Path $InstallRoot 'ServerManager\ChurchMembershipServerManager.exe'
if (-not (Test-Path -LiteralPath $managerExe)) {
    $managerExe = Join-Path $InstallRoot 'ChurchMembershipServerManager.exe'
}
if (Test-Path -LiteralPath $managerExe) {
    $regCmd = "`"$managerExe`" --background --install-root `"$InstallRoot`""
    Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'AbonaFlemoonServerManager' -Value $regCmd
}

# 5. Start Manager now if requested
if ($StartNow -and (Test-Path -LiteralPath $managerExe)) {
    Start-Process -WindowStyle Hidden -FilePath $managerExe -ArgumentList @('--background', '--install-root', "`"$InstallRoot`"") -WorkingDirectory (Split-Path -Parent $managerExe)
    
    # Wait up to 20 seconds for API ping
    $pingUrl = "http://127.0.0.1:$ApiPort/api/auth/ping"
    for ($i = 0; $i -lt 20; $i++) {
        try {
            $resp = Invoke-WebRequest -Uri $pingUrl -TimeoutSec 2 -UseBasicParsing -ErrorAction Stop
            if ($resp.StatusCode -eq 200) { break }
        } catch {}
        Start-Sleep -Seconds 1
    }
}

Write-Host 'Church Membership Sync Server installed and prepared successfully.'
} finally {
    Stop-Transcript | Out-Null
}
