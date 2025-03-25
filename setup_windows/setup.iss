; Имя установщика и выходной файл
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

; Копируем файлы
[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs
Source: ".\olm_build\*"; DestDir: "{app}\olm_build"; Flags: ignoreversion recursesubdirs

; Создаем ярлыки
[Icons]
Name: "{group}\CloudChat"; Filename: "{app}\cloudchat.exe"
Name: "{commondesktop}\CloudChat"; Filename: "{app}\cloudchat.exe"

; Добавляем папку olm_build в PATH (при удалении ничего не трогаем)
[Registry]
; Глобальное изменение (для всех пользователей, требует админ-прав)
Root: HKLM; Subkey: "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"; \
    ValueType: expandsz; ValueName: "Path"; \
    ValueData: "{olddata};{app}\olm_build"; \
    Check: NeedsAddPathToGlobal(ExpandConstant('{app}\olm_build'));

; Локальное изменение (только для текущего пользователя, не требует админ-прав)
Root: HKCU; Subkey: "Environment"; \
    ValueType: expandsz; ValueName: "Path"; \
    ValueData: "{olddata};{app}\olm_build"; \
    Check: NeedsAddPathToUser(ExpandConstant('{app}\olm_build'));

[code]
function NeedsAddPathToGlobal(Param: string): boolean;
var
  OrigPath: string;
begin
  Log('function NeedsAddPath '+Param);
  if not RegQueryStringValue(
    HKEY_LOCAL_MACHINE,
    'SYSTEM\CurrentControlSet\Control\Session Manager\Environment',
    'Path', OrigPath)
  then begin
    Result := True;
    exit;
  end;
  { look for the path with leading and trailing semicolon }
  { Pos() returns 0 if not found }
  Result :=
    (Pos(';' + UpperCase(Param) + ';', ';' + UpperCase(OrigPath) + ';') = 0) and
    (Pos(';' + UpperCase(Param) + '\;', ';' + UpperCase(OrigPath) + ';') = 0); 
end;

function NeedsAddPathToUser(Param: string): boolean;
var
  OrigPath: string;
begin
  Log('function NeedsAddPath '+Param);
  if not RegQueryStringValue(
    HKEY_CURRENT_USER,
    'Environment',
    'Path', OrigPath)
  then begin
    Result := True;
    exit;
  end;
  { look for the path with leading and trailing semicolon }
  { Pos() returns 0 if not found }
  Result :=
    (Pos(';' + UpperCase(Param) + ';', ';' + UpperCase(OrigPath) + ';') = 0) and
    (Pos(';' + UpperCase(Param) + '\;', ';' + UpperCase(OrigPath) + ';') = 0); 
end;
    
[Run]
Filename: "{app}\cloudchat.exe"; Description: "{cm:LaunchProgram,CloudChat}"; Flags: nowait postinstall skipifsilent
