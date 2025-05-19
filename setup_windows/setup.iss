[Setup]
SetupIconFile=assets/installer/icon.ico
UninstallDisplayIcon=assets/uninstaller/icon.ico
WizardImageFile=assets/installer/banner.bmp
WizardSmallImageFile=assets/installer/smallBanner.bmp
AppName=CloudChat
AppVersion=1.0
DefaultDirName={pf}\CloudChat
DefaultGroupName=CloudChat
OutputDir=Output
OutputBaseFilename=CloudChatInstaller
Compression=lzma
SolidCompression=yes

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs
Source: ".\olm_build\*"; DestDir: "{app}\olm_build"; Flags: ignoreversion recursesubdirs

[Icons]
Name: "{group}\CloudChat"; Filename: "{app}\cloudchat.exe"
Name: "{commondesktop}\CloudChat"; Filename: "{app}\cloudchat.exe"

[Registry]
Root: HKLM; Subkey: "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"; \
    ValueType: expandsz; ValueName: "Path"; \
    ValueData: "{olddata};{app}\olm_build"; \
    Check: NeedsAddPathToGlobal(ExpandConstant('{app}\olm_build'));

Root: HKCU; Subkey: "Environment"; \
    ValueType: expandsz; ValueName: "Path"; \
    ValueData: "{olddata};{app}\olm_build"; \
    Check: NeedsAddPathToUser(ExpandConstant('{app}\olm_build'));
    
[Code]

#ifdef UNICODE
  #define AW "W"
#else
  #define AW "A"
#endif
const
  SMTO_ABORTIFHUNG = 2;
  WM_WININICHANGE = $001A;
  WM_SETTINGCHANGE = WM_WININICHANGE;
type
  LONG_PTR = LongInt;
  LRESULT = LONG_PTR;  
  WPARAM = UINT_PTR;
  LPARAM = LONG_PTR;

function SendTextMessageTimeout(hWnd: HWND; Msg: UINT;
  wParam: WPARAM; lParam: string; fuFlags: UINT; 
  uTimeout: UINT; var lpdwResult: DWORD_PTR): LRESULT;
  external 'SendMessageTimeout{#AW}@user32.dll stdcall';

function NeedsAddPathToGlobal(Param: string): boolean;
var
  OrigPath: string;
begin
  Log('function NeedsAddPath ' + Param);
  if not RegQueryStringValue(
    HKEY_LOCAL_MACHINE,
    'SYSTEM\CurrentControlSet\Control\Session Manager\Environment',
    'Path', OrigPath) then
  begin
    Result := True;
    exit;
  end;

  Result :=
    (Pos(';' + UpperCase(Param) + ';', ';' + UpperCase(OrigPath) + ';') = 0) and
    (Pos(';' + UpperCase(Param) + '\;', ';' + UpperCase(OrigPath) + ';') = 0);
end;

function NeedsAddPathToUser(Param: string): boolean;
var
  OrigPath: string;
begin
  Log('function NeedsAddPath ' + Param);
  if not RegQueryStringValue(
    HKEY_CURRENT_USER,
    'Environment',
    'Path', OrigPath) then
  begin
    Result := True;
    exit;
  end;

  Result :=
    (Pos(';' + UpperCase(Param) + ';', ';' + UpperCase(OrigPath) + ';') = 0) and
    (Pos(';' + UpperCase(Param) + '\;', ';' + UpperCase(OrigPath) + ';') = 0);
end;

procedure NotifyEnvironmentChanged;
var
  ReturnCode: DWORD;
begin
  SendTextMessageTimeout(HWND_BROADCAST, WM_SETTINGCHANGE, 0,
    'Environment', SMTO_ABORTIFHUNG, 5000, ReturnCode);
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then begin
    NotifyEnvironmentChanged;
  end;
end;

[Run]
Filename: "{app}\cloudchat.exe"; Description: "{cm:LaunchProgram,CloudChat}"; Flags: nowait postinstall skipifsilent
