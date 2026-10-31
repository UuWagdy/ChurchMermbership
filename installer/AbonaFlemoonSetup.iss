#define MyAppName "Church Membership"
#define MyAppArabicName "Church Membership - العضوية الكنسية"
#ifndef MyAppVersion
  #define MyAppVersion "1.0.3"
#endif
#define MyAppPublisher "Church Membership - العضوية الكنسية"
#define MyAppExeName "church_membership.exe"
#ifndef SyncServerSource
  #define SyncServerSource "..\build\church_membership_release\server"
#endif
#ifndef ServerManagerSource
  #define ServerManagerSource "..\build\church_membership_release\manager"
#endif
#ifndef PostgresSource
  #define PostgresSource "..\build\installer_staging\pgsql"
#endif
#ifndef ToolsSource
  #define ToolsSource "..\build\installer_staging\tools"
#endif

#if !FileExists(SyncServerSource + "\coreclr.dll") || !FileExists(SyncServerSource + "\Microsoft.AspNetCore.dll")
  #error Publish the sync server with --self-contained true before compiling the installer.
#endif
#if !FileExists(ServerManagerSource + "\coreclr.dll") || !FileExists(ServerManagerSource + "\System.Windows.Forms.dll")
  #error Publish Server Manager with --self-contained true before compiling the installer.
#endif
#if !FileExists(PostgresSource + "\bin\pg_isready.exe") || !FileExists(PostgresSource + "\share\postgres.bki")
  #error Stage the complete portable PostgreSQL payload before compiling the installer.
#endif

[Setup]
AppId={{D84A91F2-6C3E-49B1-A5E8-7F2B39C14560}}
AppName={#MyAppArabicName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppArabicName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\ChurchMembership
DefaultGroupName={#MyAppArabicName}
UsePreviousAppDir=yes
DisableProgramGroupPage=yes
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.17763
WizardStyle=modern
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
OutputDir=Output
OutputBaseFilename=ChurchMembership_Setup_v{#MyAppVersion}
Compression=lzma2/fast
SolidCompression=yes
CloseApplications=yes
RestartApplications=no
ChangesAssociations=no
ChangesEnvironment=no
VersionInfoVersion={#MyAppVersion}.0
VersionInfoProductName={#MyAppArabicName}
VersionInfoDescription=Church Membership Installer with .NET 8 + PostgreSQL + SignalR Sync Server
VersionInfoCompany={#MyAppPublisher}

[Languages]
Name: "arabic"; MessagesFile: "compiler:Languages\Arabic.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Types]
Name: "client"; Description: "البرنامج فقط (افتراضي للأجهزة الفرعية والعامة)"
Name: "full"; Description: "البرنامج + سيرفر المزامنة .NET & PostgreSQL & SignalR (للجهاز الرئيسي / السيرفر)"
Name: "custom"; Description: "تثبيت مخصص"; Flags: iscustom

[Components]
Name: "client"; Description: "برنامج العضوية الكنسية (Flutter Desktop Client)"; Types: full client custom; Flags: fixed
Name: "server"; Description: "سيرفر المزامنة (.NET 8 + PostgreSQL + SignalR) مع مدير السيرفر (Server Manager)"; Types: full

[Tasks]
Name: "desktopicon"; Description: "إنشاء اختصار على سطح المكتب (Desktop Shortcut)"; GroupDescription: "اختصارات إضافية:"; Flags: checkedonce

[Dirs]
Name: "{app}\database"; Permissions: users-modify authusers-modify; Flags: uninsneveruninstall; Components: client
Name: "{app}\ChurchMembership_ServerBackups"; Permissions: users-modify authusers-modify; Flags: uninsneveruninstall; Components: server

[Files]
Source: "BACKUP_GUIDE.txt"; DestDir: "{app}"; Flags: ignoreversion; Components: client
; 1. Flutter Windows Release Payload
Source: "..\build\windows\x64\runner\Release\*"; Excludes: "abona_flemoon.exe"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: client

; 2. .NET 8 Sync Server + SignalR Hub Payload
Source: "{#SyncServerSource}\*"; DestDir: "{app}\Server\backend"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: server

; 3. AbonaFlemoonServerManager (WinForms Supervisor + Tunnels)
Source: "{#ServerManagerSource}\*"; DestDir: "{app}\ServerManager"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: server

; 4. Portable PostgreSQL Engine
Source: "{#PostgresSource}\*"; DestDir: "{app}\Server\postgresql"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: server

; 5. Cloudflare / Ngrok tools
Source: "{#ToolsSource}\*"; DestDir: "{app}\ServerManager\tools"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: server

; 6. Server PowerShell Helpers
Source: "validate-server-payload.ps1"; DestDir: "{app}\Server\installer"; Flags: ignoreversion; Components: server
Source: "install-server.ps1"; DestDir: "{app}\Server\installer"; Flags: ignoreversion; Components: server
Source: "repair-server.ps1"; DestDir: "{app}\Server\installer"; Flags: ignoreversion; Components: server
Source: "uninstall-server.ps1"; DestDir: "{app}\Server\installer"; Flags: ignoreversion; Components: client

Source: "downloads\VC_redist.x64.exe"; Flags: dontcopy
Source: "downloads\VC_redist.x86.exe"; Flags: dontcopy

[InstallDelete]
; Retire old shortcuts so Windows starts the upgraded server manager.
Type: files; Name: "{commonstartup}\Abona Flemoon Server Manager.lnk"
Type: files; Name: "{userstartup}\Abona Flemoon Server Manager.lnk"
Type: files; Name: "{autodesktop}\برنامج العضوية الكنسية - إخوة الرب.lnk"
Type: files; Name: "{autoprograms}\برنامج العضوية الكنسية - إخوة الرب.lnk"

[Icons]
Name: "{autoprograms}\{#MyAppArabicName}"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Components: client
Name: "{autodesktop}\{#MyAppArabicName}"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Tasks: desktopicon; Components: client
Name: "{autoprograms}\مدير سيرفر العضوية الكنسية"; Filename: "{app}\ServerManager\ChurchMembershipServerManager.exe"; Parameters: "--install-root ""{app}"""; WorkingDir: "{app}\ServerManager"; Components: server
Name: "{autodesktop}\مدير سيرفر العضوية الكنسية"; Filename: "{app}\ServerManager\ChurchMembershipServerManager.exe"; Parameters: "--install-root ""{app}"""; WorkingDir: "{app}\ServerManager"; Tasks: desktopicon; Components: server
Name: "{commonstartup}\Church Membership Server Manager"; Filename: "{app}\ServerManager\ChurchMembershipServerManager.exe"; Parameters: "--background --install-root ""{app}"""; WorkingDir: "{app}\ServerManager"; Components: server
Name: "{autoprograms}\معلومات سيرفر العضوية الكنسية"; Filename: "{sys}\notepad.exe"; Parameters: """{app}\SERVER_INFO.txt"""; Components: server
Name: "{autoprograms}\إصلاح سيرفر العضوية الكنسية"; Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\Server\installer\repair-server.ps1"" -InstallRoot ""{app}"""; Components: server

[Run]
; 1. Initialize PostgreSQL & Firewall for Sync Server (when server component is selected)

; 2. Launch AbonaFlemoonServerManager in background tray mode
Filename: "{app}\ServerManager\ChurchMembershipServerManager.exe"; Parameters: "--background --install-root ""{app}"""; Description: "تشغيل مدير سيرفر العضوية الكنسية (PostgreSQL + SignalR)"; Flags: nowait runasoriginaluser; Components: server

; 3. Run application after install
Filename: "{app}\{#MyAppExeName}"; Description: "تشغيل برنامج العضوية الكنسية"; Flags: nowait postinstall skipifsilent; Components: client

[UninstallRun]
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\Server\installer\uninstall-server.ps1"" -InstallRoot ""{app}"" -PreserveData"; Flags: waituntilterminated runhidden; RunOnceId: "StopAbonaFlemoonServerOnUninstall"

[Code]
var
  PrerequisiteRestart: Boolean;

function VCRuntimeInstalled(const Arch: String; const RootKey: Integer): Boolean;
var
  Key: String;
  Installed, Major, Minor, Build: Cardinal;
begin
  Key := 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\' + Arch;
  Result := RegQueryDWordValue(RootKey, Key, 'Installed', Installed) and (Installed = 1) and
    RegQueryDWordValue(RootKey, Key, 'Major', Major) and
    RegQueryDWordValue(RootKey, Key, 'Minor', Minor) and
    RegQueryDWordValue(RootKey, Key, 'Bld', Build);
  if Result then
    Result := (Major > 14) or ((Major = 14) and ((Minor > 44) or ((Minor = 44) and (Build >= 35211))));
end;

function InstallVCRuntime(const Arch: String; const RootKey: Integer): String;
var
  Name, Parameters: String;
  ExitCode, Attempt: Integer;
begin
  Result := '';
  if VCRuntimeInstalled(Arch, RootKey) then exit;
  Name := 'VC_redist.' + Arch + '.exe';
  ExtractTemporaryFile(Name);
  Parameters := '/install /quiet /norestart /log "' + ExpandConstant('{tmp}\ChurchMembership-VC-') + Arch + '.log"';
  WizardForm.PreparingLabel.Caption := 'جاري تجهيز متطلبات التشغيل Visual C++ (' + Arch + ')...';
  for Attempt := 1 to 30 do begin
    if not Exec(ExpandConstant('{tmp}\') + Name, Parameters, '', SW_HIDE, ewWaitUntilTerminated, ExitCode) then begin
      Result := 'تعذر تشغيل مثبت متطلبات Visual C++ (' + Arch + ').';
      exit;
    end;
    Log(Format('VC++ %s attempt %d exit code: %d', [Arch, Attempt, ExitCode]));
    { ERROR_INSTALL_ALREADY_RUNNING, including HRESULT_FROM_WIN32(1618). }
    if (ExitCode <> 1618) and (ExitCode <> -2147023278) then break;
    WizardForm.PreparingLabel.Caption := 'يوجد تثبيت آخر قيد التشغيل. جاري الانتظار ثم إعادة المحاولة تلقائيًا...';
    Sleep(10000);
  end;
  if (ExitCode = 3010) or (ExitCode = 1641) then PrerequisiteRestart := True
  else if (ExitCode <> 0) and (ExitCode <> 1638) and (ExitCode <> -2147023258) then begin
    Result := Format('فشل تثبيت متطلبات Visual C++ (%s)، كود %d. أغلق أي تثبيت آخر ثم أعد المحاولة. السجل: ', [Arch, ExitCode]) + ExpandConstant('{tmp}\ChurchMembership-VC-') + Arch + '.log';
    exit;
  end;
  if not PrerequisiteRestart and not VCRuntimeInstalled(Arch, RootKey) then
    Result := 'لم يكتمل تجهيز متطلبات Visual C++ (' + Arch + '). أعد تشغيل Windows ثم أعد تشغيل المثبت.';
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  Result := InstallVCRuntime('x64', HKLM64);
  if Result = '' then Result := InstallVCRuntime('x86', HKLM32);
  NeedsRestart := PrerequisiteRestart;
  if NeedsRestart and (Result = '') then
    Result := 'تم تثبيت متطلبات التشغيل. أعد تشغيل Windows ثم شغّل المثبت مرة أخرى لإكمال تثبيت البرنامج.';
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  Parameters: String;
  ExitCode: Integer;
begin
  if (CurStep = ssPostInstall) and WizardIsComponentSelected('server') then begin
    WizardForm.StatusLabel.Caption := 'جاري تجهيز PostgreSQL وسيرفر المزامنة...';
    Parameters := '-NoProfile -ExecutionPolicy Bypass -File "' + ExpandConstant('{app}\Server\installer\install-server.ps1') +
      '" -InstallRoot "' + ExpandConstant('{app}') + '" -InstallerVersion "{#MyAppVersion}"';
    if not Exec(ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe'), Parameters, '', SW_HIDE, ewWaitUntilTerminated, ExitCode) then
      RaiseException('تعذر تشغيل تجهيز السيرفر. أعد تشغيل المثبت.');
    if ExitCode <> 0 then
      RaiseException('فشل تجهيز السيرفر. راجع logs\install-server.log داخل %LOCALAPPDATA%\ChurchMembership_ServerData ثم أعد تشغيل المثبت.');
  end;
end;
