[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$InstallRoot,
    [switch]$PreserveData
)

$ErrorActionPreference = 'SilentlyContinue'

& taskkill.exe /F /IM 'ChurchMembershipServerManager.exe' /T 2>&1 | Out-Null
& taskkill.exe /F /IM 'ChurchMembership.SyncServer.exe' /T 2>&1 | Out-Null
Get-Process -Name 'church_membership','ChurchMembershipServerManager','ChurchMembership.SyncServer','abona_flemoon','AbonaFlemoonServerManager','AbonaFlemoon.SyncServer' -ErrorAction SilentlyContinue |
    Stop-Process -Force -ErrorAction SilentlyContinue

& netsh.exe advfirewall firewall delete rule name='AbonaFlemoon Sync Server (5060)' 2>&1 | Out-Null
& netsh.exe advfirewall firewall delete rule name='Church Membership Sync Server (5060)' 2>&1 | Out-Null
& netsh.exe advfirewall firewall delete rule name='Church Membership PostgreSQL (5438)' 2>&1 | Out-Null
& netsh.exe advfirewall firewall delete rule name='AbonaFlemoon PostgreSQL (5435)' 2>&1 | Out-Null

Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'AbonaFlemoonServerManager' -ErrorAction SilentlyContinue

if (-not $PreserveData) {
    $localAppData = [Environment]::GetFolderPath('LocalApplicationData')
    foreach ($folder in @('ChurchMembership_ServerData', 'AbonaFlemoon_ServerData')) {
        $serverData = [IO.Path]::GetFullPath((Join-Path $localAppData $folder))
        $expected = [IO.Path]::GetFullPath($localAppData).TrimEnd('\') + '\' + $folder
        if ($serverData -eq $expected -and (Test-Path -LiteralPath $serverData)) {
            Remove-Item -LiteralPath $serverData -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

exit 0
