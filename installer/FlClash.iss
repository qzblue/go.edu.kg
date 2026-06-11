; ============================================================
;  美国华人华侨贸易中心 加速器 — Inno Setup 安装脚本  v1.0
;  仓库内相对路径版（在 source/installer/ 下用 ISCC 编译）
;  先 `flutter build windows --release --dart-define-from-file=env.json`
;  生成 ..\build\windows\x64\runner\Release，再 `ISCC FlClash.iss`
; ============================================================
#define MyAppName "美国华人华侨贸易中心"
#define MyAppVersion "1.0"
#define MyAppPublisher "美国华人华侨贸易中心"
#define MyAppURL "https://go.edu.kg"
#define MyAppExeName "FlClash.exe"
#define SrcDir "..\build\windows\x64\runner\Release"
#define IconFile "..\assets\images\icon.ico"

[Setup]
AppId={{8F3A2C71-6B4E-4D2A-9C1F-0E1D2C3B4A50}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} v{#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
VersionInfoVersion=1.0.0.0
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription={#MyAppName} 安装程序
VersionInfoProductName={#MyAppName}

; —— 默认安装到 D 盘，可自行更换路径 ——
DefaultDirName=D:\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
DisableWelcomePage=no
AllowNoIcons=yes
UsePreviousAppDir=yes

; —— 安装包外观（成熟产品风格）——
WizardStyle=modern
WizardSizePercent=110
WizardImageFile=wizard_large.bmp,wizard_large@2x.bmp
WizardSmallImageFile=wizard_small.bmp,wizard_small@2x.bmp
WizardImageStretch=yes
SetupIconFile={#IconFile}
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}

; —— 输出 ——
OutputDir=dist
OutputBaseFilename=美国华人华侨贸易中心_v1.0_安装包
Compression=lzma2/ultra64
SolidCompression=yes
LZMANumBlockThreads=4

; —— 平台/权限 ——
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
MinVersion=10.0
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "chinesesimp"; MessagesFile: "ChineseSimplified.isl"

[Tasks]
; 默认勾选 → 默认自动创建桌面快捷方式
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#SrcDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; 开始菜单
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\卸载 {#MyAppName}"; Filename: "{uninstallexe}"
; 桌面（默认创建）
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}"
