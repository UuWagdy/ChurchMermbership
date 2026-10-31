# Installer startup repair — 22 October 2026

Applies to Sunday School and the corresponding Church Membership project at
`E:\el odwia\project`. Installer version: **1.0.2**; Flutter application payloads
are the existing Windows release builds. No Flutter application features changed.

## Evidence

The supplied `Downloads\ss` manager log shows PostgreSQL starting successfully,
but sometimes taking longer than the manager's 30-second startup allowance.
The backend did not reach health within its 35-second allowance. No backend error
output in those logs proves a missing .NET runtime. The separate ASP.NET installer
log failed with `0x80070652` (Windows Installer busy / error 1618).

The existing backend and manager payloads already use self-contained .NET.
Microsoft documents that [self-contained deployments include their runtime](https://learn.microsoft.com/dotnet/core/deploying/)
and that [1618 means another installation is in progress](https://learn.microsoft.com/windows/win32/msi/error-codes).

## Changes

- Embed the existing complete .NET, ASP.NET, Windows Desktop and portable
  PostgreSQL payloads. Validate their native runtime files and runtime configuration
  during the build and server installation. Reject incomplete or framework-dependent
  payloads; require PostgreSQL at installer compilation.
- Bundle Visual C++ x64/x86 for offline installation. Detect an equal/newer runtime,
  check installer exit codes, retry a busy Windows Installer for up to 30 attempts
  with 10 seconds between attempts, and handle required restart explicitly.
  Build scripts download missing VC packages from Microsoft's endpoint.
- Check server preparation exit codes before launching the manager. Preserve
  preparation diagnostics in `logs\install-server.log`; repair scripts propagate
  failed preparation instead of claiming success.
- Wait for `pg_isready`, not just an open TCP port. Allow three minutes for
  PostgreSQL readiness and five minutes for backend health. Bypass system HTTP
  proxies for local manager health checks. Include the exit code if the backend exits.
- During installation, validate the actual PostgreSQL data directory. Reuse an
  already running matching cluster; stop a bootstrap cluster only if this invocation
  started it. Check database creation and firewall command results.
- Keep the two projects' database names, ports, storage paths and membership legacy
  migration behavior. Remove manager runtime fallback paths into other projects.
  Reuse the previous Sunday School installation directory during upgrades, including
  custom drive locations, so the manager continues to find the existing data.

## Validation

- Published both Windows managers successfully as self-contained win-x64 folders.
- Validated both full packaged payloads; rejected incomplete and framework-dependent
  test payloads.
- Ran `tool/InstallerSmokeTests` and the equivalent membership
  `scripts/InstallerSmokeTests` against copied packaged EXEs and PostgreSQL on
  temporary roots with spaces and dynamically allocated ports. Both passed first
  startup, schema initialization, health, restart and stop. Tested with invalid
  `DOTNET_ROOT` / `DOTNET_ROOT_X64`, disabled multilevel lookup and an unusable HTTP
  proxy. The live installations and their databases were not used.
- Tested the Sunday School installer database preparation on a new temporary cluster
  using Windows PowerShell 5.1 and `-PrepareDatabaseOnly`, avoiding firewall,
  startup registration and shared server-info changes. Passed.
- Tested the membership preparation on its initialized temporary cluster using the
  same isolated mode. Passed.
- Compiled both Inno Setup installers. Compilation verifies the Pascal code and
  packaged file references; it does not execute prerequisite installation.

The complete installer UI, VC installation/reboot and busy-MSI retry still need
verification on a clean Windows machine. No installer was run against the user's
installed applications. Existing Flutter releases were reused; no APK was rebuilt.
