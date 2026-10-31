@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
cd /d "%~dp0"

echo ================================================================
echo  Church Membership - بناء مثبت الويندوز وملف الـ APK في فولدر dist
echo ================================================================
echo.

set "DIST_DIR=%~dp0dist"
if not exist "!DIST_DIR!" (
    mkdir "!DIST_DIR!"
)

echo ===================================================
echo [1/6] جاري بناء تطبيق الأندرويد Flutter APK (Release)...
echo ===================================================
call flutter build apk --release
if errorlevel 1 (
    echo [ERROR] فشل بناء ملف الأندرويد APK!
    exit /b 1
)

echo.
echo ===================================================
echo [2/6] جاري بناء تطبيق الويندوز Flutter Windows Release...
echo ===================================================
call flutter build windows --release
if errorlevel 1 (
    echo [ERROR] فشل بناء تطبيق الويندوز Flutter Windows!
    exit /b 1
)

echo.
echo ===================================================
echo [3/6] جاري نشر سيرفر المزامنة .NET 8 Sync Server...
echo ===================================================
dotnet publish "AbonaFlemoon.SyncServer\AbonaFlemoon.SyncServer.csproj" -c Release -r win-x64 --self-contained true -o "build\church_membership_release\server"
if errorlevel 1 (
    echo [ERROR] فشل نشر SyncServer!
    exit /b 1
)

echo.
echo ===================================================
echo [4/6] جاري نشر مدير السيرفر Church Membership Server Manager...
echo ===================================================
dotnet publish "AbonaFlemoonServerManager\AbonaFlemoonServerManager.csproj" -c Release -r win-x64 --self-contained true -p:PublishSingleFile=false -o "build\church_membership_release\manager"
if errorlevel 1 (
    echo [ERROR] فشل نشر Server Manager!
    exit /b 1
)

echo.
echo ===================================================
echo [5/6] تجهيز PostgreSQL والأدوات وتجميع مثبت الويندوز Inno Setup...
echo ===================================================
if not exist "build\installer_staging\pgsql\bin\postgres.exe" (
    if exist "E:\Sunday School\Server\postgresql\bin\postgres.exe" (
        echo نسخ pgsql المحمول من Sunday School...
        xcopy /E /I /Y "E:\Sunday School\Server\postgresql" "build\installer_staging\pgsql"
    ) else if exist "E:\Al Ragaa\Server\postgresql\bin\postgres.exe" (
        echo نسخ pgsql المحمول من Al Ragaa...
        xcopy /E /I /Y "E:\Al Ragaa\Server\postgresql" "build\installer_staging\pgsql"
    ) else if exist "E:\Final\petros_pols_flutter\build\installer_staging\pgsql\bin\postgres.exe" (
        echo نسخ pgsql المحمول من petros_pols_flutter...
        xcopy /E /I /Y "E:\Final\petros_pols_flutter\build\installer_staging\pgsql" "build\installer_staging\pgsql"
    ) else if exist "E:\POWER\Offline_First_Sync\sales_flutter_app\DrSalesServerManager\pgsql\bin\postgres.exe" (
        echo نسخ pgsql المحمول من DrSalesServerManager...
        xcopy /E /I /Y "E:\POWER\Offline_First_Sync\sales_flutter_app\DrSalesServerManager\pgsql" "build\installer_staging\pgsql"
    ) else (
        echo [ERROR] Portable PostgreSQL is required in build\installer_staging\pgsql.
        exit /b 1
    )
)

if not exist "build\installer_staging\tools\cloudflared.exe" (
    if exist "E:\Sunday School\ServerManager\tools\cloudflared.exe" (
        echo نسخ الأدوات من Sunday School...
        xcopy /E /I /Y "E:\Sunday School\ServerManager\tools" "build\installer_staging\tools"
    ) else if exist "E:\Final\petros_pols_flutter\build\installer_staging\tools\cloudflared.exe" (
        echo نسخ الأدوات من petros_pols_flutter...
        xcopy /E /I /Y "E:\Final\petros_pols_flutter\build\installer_staging\tools" "build\installer_staging\tools"
    ) else if exist "E:\POWER\Offline_First_Sync\sales_flutter_app\DrSalesServerManager\tools\cloudflared.exe" (
        echo نسخ الأدوات من DrSalesServerManager...
        xcopy /E /I /Y "E:\POWER\Offline_First_Sync\sales_flutter_app\DrSalesServerManager\tools" "build\installer_staging\tools"
    ) else (
        mkdir "build\installer_staging\tools" 2>nul
    )
)

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
        echo [ERROR] فشل تجميع مثبت Inno Setup!
        exit /b 1
    )
) else (
    echo [WARNING] لم يتم العثور على ISCC.exe في المسار الافتراضي لـ Inno Setup.
)

echo.
echo ===================================================
echo [6/6] تجميع المثبت وملف الـ APK داخل فولدر dist...
echo ===================================================
if exist "installer\Output\ChurchMembership_Setup_v1.0.3.exe" (
    copy /Y "installer\Output\ChurchMembership_Setup_v1.0.3.exe" "!DIST_DIR!\"
) else (
    for %%F in ("installer\Output\*.exe") do (
        copy /Y "%%F" "!DIST_DIR!\"
    )
)

if exist "build\app\outputs\flutter-apk\app-release.apk" (
    copy /Y "build\app\outputs\flutter-apk\app-release.apk" "!DIST_DIR!\ChurchMembership_v1.0.3.apk"
)

echo.
echo ================================================================
echo  تم بنجاح بناء المثبت والـ APK ووضعهما في فولدر dist:
echo ================================================================
dir /b "!DIST_DIR!"
echo ================================================================
echo مسار الفولدر: !DIST_DIR!
echo ================================================================
