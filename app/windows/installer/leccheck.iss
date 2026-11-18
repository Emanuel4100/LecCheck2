; LecCheck's setup for Windows (Inno Setup 6), built by scripts/windows_build.ps1
; from `flutter build windows --release` (with the VC++ runtime copied in).
;
; It installs for the current user only, so it never asks for admin rights, in
; %LOCALAPPDATA%\Programs\LecCheck. The same setup updates LecCheck: the app
; downloads it, checks its SHA-256 and runs it with
; /SILENT /NORESTART /RELAUNCH=1 /LOG=... (lib/core/update/windows_install.dart).
;
; Never change AppId: Windows and the setup know an installed LecCheck by it.
; The data (%APPDATA%\com.leccheck\LecCheck) is never touched, uninstalling too.

#ifndef AppVersion
  #define AppVersion "0.0.0-dev"
#endif
; Numbers only (major.minor.patch.build), for the setup's file properties.
#ifndef AppNumericVersion
  #define AppNumericVersion "0.0.0.0"
#endif
#ifndef BuildDir
  #define BuildDir "..\..\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "..\..\build\windows\installer"
#endif

; Held by the running app (windows/runner/main.cpp).
#define AppMutex "LecCheck.com.leccheck.app"

[Setup]
AppId={{7D49E649-14CD-4DF2-BE7F-7EC3EA3FF682}
AppName=LecCheck
AppVersion={#AppVersion}
AppVerName=LecCheck {#AppVersion}
AppPublisher=Emanuel
AppPublisherURL=https://github.com/Emanuel4100/LecCheck2
AppSupportURL=https://github.com/Emanuel4100/LecCheck2/issues
AppUpdatesURL=https://github.com/Emanuel4100/LecCheck2/releases
AppCopyright=Copyright (C) 2026 Emanuel. Licensed under the GNU GPL v3 or later.
VersionInfoVersion={#AppNumericVersion}
VersionInfoProductVersion={#AppNumericVersion}
VersionInfoProductTextVersion={#AppVersion}
VersionInfoDescription=LecCheck setup
DefaultDirName={localappdata}\Programs\LecCheck
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; Windows 10 1903: the time zone comes from Windows' own ICU (icu.dll).
MinVersion=10.0.18362
WizardStyle=modern
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\leccheck.exe
UninstallDisplayName=LecCheck
OutputDir={#OutputDir}
OutputBaseFilename=LecCheck-{#AppVersion}-windows-setup
Compression=lzma2/max
SolidCompression=yes
; The code below waits for LecCheck to close instead.
CloseApplications=no
RestartApplications=no
; One setup at a time.
SetupMutex=LecCheckSetup.com.leccheck.app
ShowLanguageDialog=auto

[Languages]
Name: "en"; MessagesFile: "compiler:Default.isl"
Name: "he"; MessagesFile: "compiler:Languages\Hebrew.isl"

[CustomMessages]
en.CloseLecCheck=LecCheck is open. Close it, then choose OK to continue.
he.CloseLecCheck=LecCheck פתוחה. סגרו אותה ובחרו "אישור" כדי להמשיך.

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[InstallDelete]
; Flutter's assets are replaced whole, so none of an older version's stay.
Type: filesandordirs; Name: "{app}\data"

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; The same app id as the running app (main.cpp), so a pinned LecCheck and the
; open one are one taskbar button.
Name: "{autoprograms}\LecCheck"; Filename: "{app}\leccheck.exe"; AppUserModelID: "com.leccheck.app"
Name: "{autodesktop}\LecCheck"; Filename: "{app}\leccheck.exe"; AppUserModelID: "com.leccheck.app"; Tasks: desktopicon

[Run]
Filename: "{app}\leccheck.exe"; Description: "{cm:LaunchProgram,LecCheck}"; Flags: nowait postinstall skipifsilent
; An update from inside the app: open the new version.
Filename: "{app}\leccheck.exe"; Flags: nowait; Check: Relaunch

[Code]
function Relaunch: Boolean;
begin
  Result := ExpandConstant('{param:RELAUNCH|0}') = '1';
end;

{ Whether LecCheck is closed, waiting up to Seconds for it to close. }
function LecCheckClosed(Seconds: Integer): Boolean;
var
  I: Integer;
begin
  for I := 1 to Seconds * 2 do
  begin
    if not CheckForMutexes('{#AppMutex}') then
    begin
      Result := True;
      Exit;
    end;
    Sleep(500);
  end;
  Result := not CheckForMutexes('{#AppMutex}');
end;

{ An update from inside the app quits LecCheck right after starting this
  setup: wait for it. Started by hand while LecCheck is open: ask to close it. }
function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  Result := '';
  if WizardSilent then
  begin
    if not LecCheckClosed(30) then
      Result := CustomMessage('CloseLecCheck');
    Exit;
  end;
  while not LecCheckClosed(1) do
    if MsgBox(CustomMessage('CloseLecCheck'), mbInformation, MB_OKCANCEL) = IDCANCEL then
    begin
      Result := CustomMessage('CloseLecCheck');
      Exit;
    end;
end;

function InitializeUninstall: Boolean;
begin
  Result := True;
  while not LecCheckClosed(1) do
  begin
    if UninstallSilent then
    begin
      Result := False;
      Exit;
    end;
    if MsgBox(CustomMessage('CloseLecCheck'), mbInformation, MB_OKCANCEL) = IDCANCEL then
    begin
      Result := False;
      Exit;
    end;
  end;
end;
