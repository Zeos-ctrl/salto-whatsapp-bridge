#define MyAppName "Salto-WhatsApp Bridge"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Darren Bryan Security Services"
#define MyAppURL "https://darrenbryansecurityservices.co.uk/"
#define MyAppExeName "salto-whatsapp-bridge.exe"

[Setup]
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
OutputDir=output
OutputBaseFilename=SaltoWhatsAppBridge-Setup-{#MyAppVersion}
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesInstallIn64BitMode=x64

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "service"; Description: "Install as Windows Service (runs automatically on startup)"; GroupDescription: "Service Options:"; Flags: checkedonce

[Files]
; Main executable
Source: "..\dist\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion

; Source files needed for service
Source: "..\src\server.js"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\src\public\*"; DestDir: "{app}\public"; Flags: ignoreversion recursesubdirs createallsubdirs

; Dependencies
Source: "..\node_modules\*"; DestDir: "{app}\node_modules"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\package.json"; DestDir: "{app}"; Flags: ignoreversion

; Configuration
Source: "..\..env.example"; DestDir: "{app}"; DestName: ".env.example"; Flags: ignoreversion; AfterInstall: CreateEnvFile

; Service scripts
Source: "install-service.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "install-service-script.js"; DestDir: "{app}"; Flags: ignoreversion
Source: "uninstall-service.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "uninstall-service-script.js"; DestDir: "{app}"; Flags: ignoreversion

; Documentation
Source: "README.md"; DestDir: "{app}"; Flags: ignoreversion isreadme; AfterInstall: CreateReadme
Source: "LICENSE.txt"; DestDir: "{app}"; Flags: ignoreversion; AfterInstall: CreateLicense

[Dirs]
Name: "{app}\whatsapp-session"; Permissions: users-full

[Icons]
Name: "{group}\{#MyAppName} Configuration"; Filename: "http://localhost:3000"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "http://localhost:3000"; Tasks: desktopicon

[Run]
Filename: "{app}\install-service.bat"; Parameters: ""; WorkingDir: "{app}"; Flags: runhidden waituntilterminated; Tasks: service; Description: "Installing Windows Service"
Filename: "http://localhost:3000"; Flags: shellexec postinstall skipifsilent; Description: "Open Salto-WhatsApp Bridge Configuration"

[UninstallRun]
Filename: "{app}\uninstall-service.bat"; Parameters: ""; WorkingDir: "{app}"; Flags: runhidden waituntilterminated

[Code]
function InitializeSetup(): Boolean;
begin
  // Check if Node.js is installed
  if not RegKeyExists(HKEY_LOCAL_MACHINE, 'SOFTWARE\Node.js') and
     not RegKeyExists(HKEY_LOCAL_MACHINE, 'SOFTWARE\WOW6432Node\Node.js') then
  begin
    MsgBox('Node.js is not installed. Please install Node.js v18 or higher from https://nodejs.org/ before continuing.', mbError, MB_OK);
    Result := False;
  end
  else
    Result := True;
end;

procedure CreateEnvFile();
var
  EnvPath: String;
begin
  EnvPath := ExpandConstant('{app}\.env');
  if not FileExists(EnvPath) then
  begin
    SaveStringToFile(EnvPath, 'PORT=3000' + #13#10 + 'WHATSAPP_TARGETS=' + #13#10, False);
  end;
end;

procedure CreateReadme();
var
  ReadmePath: String;
begin
  ReadmePath := ExpandConstant('{app}\README.md');
  if not FileExists(ReadmePath) then
  begin
    SaveStringToFile(ReadmePath, '# Salto-WhatsApp Bridge' + #13#10 + 'See INSTALL.txt for instructions.' + #13#10, False);
  end;
end;

procedure CreateLicense();
var
  LicensePath: String;
begin
  LicensePath := ExpandConstant('{app}\LICENSE.txt');
  if not FileExists(LicensePath) then
  begin
    SaveStringToFile(LicensePath, 'MIT License' + #13#10, False);
  end;
end;
