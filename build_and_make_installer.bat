@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

echo ===================================================
echo [1/5] Building Flutter Windows Release Application...
echo ===================================================
call flutter build windows --release
if errorlevel 1 (
    echo [ERROR] Flutter build windows failed.
    exit /b 1
)

echo.
echo ===================================================
echo [2/5] Publishing .NET 8 Sync Server...
echo ===================================================
dotnet publish "AbonaFlemoon.SyncServer\AbonaFlemoon.SyncServer.csproj" -c Release -r win-x64 --self-contained true -o "build\church_membership_release\server"
if errorlevel 1 (
    echo [ERROR] Publishing SyncServer failed.
    exit /b 1
)

echo.
echo ===================================================
echo [3/5] Publishing Church Membership Server Manager...
echo ===================================================
dotnet publish "AbonaFlemoonServerManager\AbonaFlemoonServerManager.csproj" -c Release -r win-x64 --self-contained true -p:PublishSingleFile=false -o "build\church_membership_release\manager"
if errorlevel 1 (
    echo [ERROR] Publishing Server Manager failed.
    exit /b 1
)

echo.
echo ===================================================
echo [4/5] Staging Portable PostgreSQL and Tools...
echo ===================================================
if not exist "build\installer_staging\pgsql\bin\postgres.exe" (
    if exist "E:\Sunday School\Server\postgresql\bin\postgres.exe" (
        echo Copying portable pgsql from Sunday School...
        xcopy /E /I /Y "E:\Sunday School\Server\postgresql" "build\installer_staging\pgsql"
    ) else if exist "E:\Al Ragaa\Server\postgresql\bin\postgres.exe" (
        echo Copying portable pgsql from Al Ragaa...
        xcopy /E /I /Y "E:\Al Ragaa\Server\postgresql" "build\installer_staging\pgsql"
    ) else if exist "E:\Final\petros_pols_flutter\build\installer_staging\pgsql\bin\postgres.exe" (
        echo Copying portable pgsql from reference project...
        xcopy /E /I /Y "E:\Final\petros_pols_flutter\build\installer_staging\pgsql" "build\installer_staging\pgsql"
    ) else if exist "E:\POWER\Offline_First_Sync\sales_flutter_app\DrSalesServerManager\pgsql\bin\postgres.exe" (
        echo Copying portable pgsql from DrSalesServerManager...
        xcopy /E /I /Y "E:\POWER\Offline_First_Sync\sales_flutter_app\DrSalesServerManager\pgsql" "build\installer_staging\pgsql"
    ) else (
        echo [ERROR] Portable PostgreSQL is required in build\installer_staging\pgsql.
        exit /b 1
    )
)

if not exist "build\installer_staging\tools\cloudflared.exe" (
    if exist "E:\Sunday School\ServerManager\tools\cloudflared.exe" (
        echo Copying tools from Sunday School...
        xcopy /E /I /Y "E:\Sunday School\ServerManager\tools" "build\installer_staging\tools"
    ) else if exist "E:\Final\petros_pols_flutter\build\installer_staging\tools\cloudflared.exe" (
        echo Copying tools from reference project...
        xcopy /E /I /Y "E:\Final\petros_pols_flutter\build\installer_staging\tools" "build\installer_staging\tools"
    ) else if exist "E:\POWER\Offline_First_Sync\sales_flutter_app\DrSalesServerManager\tools\cloudflared.exe" (
        echo Copying tools from DrSalesServerManager...
        xcopy /E /I /Y "E:\POWER\Offline_First_Sync\sales_flutter_app\DrSalesServerManager\tools" "build\installer_staging\tools"
    ) else (
        mkdir "build\installer_staging\tools" 2>nul
    )
)

echo.
echo ===================================================
echo [5/5] Compiling Inno Setup Installer...
echo ===================================================
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "installer\validate-server-payload.ps1" -BackendRoot "build\church_membership_release\server" -ManagerRoot "build\church_membership_release\manager" -PostgresRoot "build\installer_staging\pgsql"
if errorlevel 1 exit /b 1
for %%A in (x64 x86) do (
    if not exist "installer\downloads\VC_redist.%%A.exe" (
        powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; New-Item -ItemType Directory -Force 'installer\downloads' | Out-Null; Invoke-WebRequest -UseBasicParsing 'https://aka.ms/vs/17/release/vc_redist.%%A.exe' -OutFile 'installer\downloads\VC_redist.%%A.exe'; $signature = Get-AuthenticodeSignature 'installer\downloads\VC_redist.%%A.exe'; if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notlike '*Microsoft Corporation*') { throw 'Invalid Microsoft redistributable signature' }"
        if errorlevel 1 exit /b 1
    )
)
set "ISCC_PATH=C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
if not exist "!ISCC_PATH!" (
    set "ISCC_PATH=C:\Program Files\Inno Setup 6\ISCC.exe"
)

if exist "!ISCC_PATH!" (
    "!ISCC_PATH!" "installer\AbonaFlemoonSetup.iss"
    if errorlevel 1 (
        echo [ERROR] Inno Setup compilation failed.
        exit /b 1
    )
    echo [SUCCESS] Setup executable generated at installer\Output\ChurchMembership_Setup_v1.0.3.exe
    if not exist "dist" mkdir "dist"
    copy /Y "installer\Output\ChurchMembership_Setup_v1.0.3.exe" "dist\"
) else (
    echo [WARNING] ISCC.exe not found at default paths. You can compile installer\AbonaFlemoonSetup.iss manually with Inno Setup.
)

echo.
echo ===================================================
echo Build pipeline completed successfully!
echo Installer copied to: dist\
echo ===================================================
