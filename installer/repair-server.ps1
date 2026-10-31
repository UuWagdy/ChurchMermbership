[CmdletBinding()]
param(
    [string]$InstallRoot,
    [string]$DataRoot,
    [int]$ApiPort = 5060,
    [int]$DatabasePort = 5438
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($InstallRoot)) {
    $InstallRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
}
$InstallRoot = [IO.Path]::GetFullPath($InstallRoot).TrimEnd('\', '/')

if ([string]::IsNullOrWhiteSpace($DataRoot)) {
    $localAppData = [Environment]::GetFolderPath('LocalApplicationData')
    $DataRoot = Join-Path $localAppData 'ChurchMembership_ServerData'
    $legacyData = Join-Path $localAppData 'AbonaFlemoon_ServerData'
    if (-not (Test-Path -LiteralPath (Join-Path $DataRoot 'pgdata\PG_VERSION')) -and (Test-Path -LiteralPath (Join-Path $legacyData 'pgdata\PG_VERSION'))) { $DataRoot = $legacyData }
}

Write-Host 'Stopping Church Membership Server Manager & Sync Server...' -ForegroundColor Cyan
& taskkill.exe /F /IM 'ChurchMembershipServerManager.exe' /T 2>&1 | Out-Null
& taskkill.exe /F /IM 'ChurchMembership.SyncServer.exe' /T 2>&1 | Out-Null

$backupRoot = Join-Path $InstallRoot 'ChurchMembership_ServerBackups'
$backupPath = Join-Path $backupRoot "repair-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
if (Test-Path -LiteralPath $DataRoot) {
    New-Item -ItemType Directory -Force -Path $backupPath | Out-Null
    & robocopy.exe $DataRoot $backupPath /E /COPY:DAT /R:2 /W:1 /NP /NFL /NDL 2>&1 | Out-Null
}

$installScript = Join-Path $InstallRoot 'Server\installer\install-server.ps1'
if (-not (Test-Path -LiteralPath $installScript)) {
    $installScript = Join-Path $PSScriptRoot 'install-server.ps1'
}
if (Test-Path -LiteralPath $installScript -PathType Leaf) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $installScript -InstallRoot $InstallRoot -DataRoot $DataRoot -ApiPort $ApiPort -DatabasePort $DatabasePort
    if ($LASTEXITCODE -ne 0) { throw 'Server preparation failed. See the server data logs\install-server.log.' }
}

$managerExe = Join-Path $InstallRoot 'ServerManager\ChurchMembershipServerManager.exe'
if (-not (Test-Path -LiteralPath $managerExe)) {
    $managerExe = Join-Path $InstallRoot 'ChurchMembershipServerManager.exe'
}
if (Test-Path -LiteralPath $managerExe -PathType Leaf) {
    Start-Process -WindowStyle Hidden -FilePath $managerExe -ArgumentList @('--background', '--install-root', "`"$InstallRoot`"") -WorkingDirectory (Split-Path -Parent $managerExe)
}

Write-Host 'Church Membership Server repaired and restarted successfully.' -ForegroundColor Green
