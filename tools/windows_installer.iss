#define MyAppName "雨滴云"
#define MyAppVersion "1.1.0"
#define MyAppPublisher "YudiCloud"
#define MyAppURL "https://cn3.yudijiasu.vip/"
#define MyAppExeName "FlClash.exe"
#define SourceDir "E:\claude coding\FlClash\source\build\windows\x64\runner\Release"
#define OutputDir "E:\claude coding\FlClash\source\dist"
#define IconFile "E:\claude coding\FlClash\source\assets\images\icon.ico"

[Setup]
AppId={{A8F3D2C1-5B7E-4A9F-8C3D-1E2F4B5C6D7A}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=no
OutputDir={#OutputDir}
OutputBaseFilename=YudiCloud_Setup_v{#MyAppVersion}
SetupIconFile={#IconFile}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName} {#MyAppVersion}
CloseApplications=yes
RestartApplications=no
WizardImageFile=compiler:WizClassicImage.bmp
WizardSmallImageFile=compiler:WizClassicSmallImage.bmp

[Languages]
Name: "chinesesimp"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"
Name: "startupicon"; Description: "开机时自动启动"; GroupDescription: "启动选项:"; Flags: unchecked

[Files]
; Main executable and all DLLs
Source: "{#SourceDir}\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\FlClashCore.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\FlClashHelperService.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\EnableLoopback.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\flutter_windows.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\app_links_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\connectivity_plus_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\dynamic_color_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\file_selector_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\flutter_js_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\hotkey_manager_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\proxy_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\quickjs_c_bridge.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\screen_retriever_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\sqlite3.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\sqlite3_flutter_libs_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\tray_manager_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\url_launcher_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\window_ext_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\window_manager_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
; Data folder (Flutter assets, fonts, etc.)
Source: "{#SourceDir}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"
Name: "{group}\卸载 {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Registry]
; Startup registry entry (optional task)
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "{#MyAppName}"; ValueData: """{app}\{#MyAppExeName}"" --launch-at-startup"; Flags: uninsdeletevalue; Tasks: startupicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall

[UninstallDelete]
Type: filesandordirs; Name: "{userappdata}\fl_clash"
Type: filesandordirs; Name: "{localappdata}\fl_clash"
