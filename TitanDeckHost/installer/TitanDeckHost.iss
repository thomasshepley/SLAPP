; TitanDeck Host installer (Inno Setup 6). Built by .github/workflows/host.yml:
;   iscc /DAppVersion=0.1.0 /DPublishDir=..\publish installer\TitanDeckHost.iss
; Installs the service (LocalSystem, starts at boot), the tray app (starts at
; login), the drop folders and firewall rules for private networks.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef PublishDir
  #define PublishDir "..\publish"
#endif

[Setup]
AppId={{6B0D6C7E-5B7D-4E1A-9B66-9C2B7A3E2F10}
AppName=TitanDeck Host
AppVersion={#AppVersion}
AppPublisher=Elex Productions
DefaultDirName={autopf}\TitanDeck Host
DefaultGroupName=TitanDeck Host
DisableProgramGroupPage=yes
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\out
OutputBaseFilename=TitanDeckHost-Setup-{#AppVersion}
WizardStyle=modern
Compression=lzma2
SolidCompression=yes
CloseApplications=yes
SetupIconFile=..\src\App\Assets\TitanDeckHost.ico
UninstallDisplayIcon={app}\TitanDeckHost.exe
UninstallDisplayName=TitanDeck Host

[Files]
Source: "{#PublishDir}\service\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs
Source: "{#PublishDir}\app\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs
Source: "{#PublishDir}\rdpwrap\rdpwrap.ini"; DestDir: "{app}\rdpwrap"; Flags: ignoreversion skipifsourcedoesntexist
Source: "..\CHANGELOG.md"; DestDir: "{app}"; Flags: ignoreversion

[Dirs]
Name: "{commondocs}\TitanDeck\To PC"
Name: "{commondocs}\TitanDeck\To iPad"
Name: "{commonappdata}\TitanDeck Host"

[Icons]
Name: "{group}\TitanDeck Host"; Filename: "{app}\TitanDeckHost.exe"
Name: "{commondesktop}\TitanDeck Host"; Filename: "{app}\TitanDeckHost.exe"
Name: "{commondesktop}\TitanDeck To PC"; Filename: "{commondocs}\TitanDeck\To PC"

[Registry]
; Tray icon at every login.
Root: HKLM; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "TitanDeckHost"; ValueData: """{app}\TitanDeckHost.exe"" --tray"; Flags: uninsdeletevalue

[Run]
Filename: "{sys}\sc.exe"; Parameters: "create TitanDeckHost binPath= ""{app}\TitanDeckHost.Service.exe"" start= auto DisplayName= ""TitanDeck Host"""; Flags: runhidden; StatusMsg: "Installing the service..."
Filename: "{sys}\sc.exe"; Parameters: "config TitanDeckHost binPath= ""{app}\TitanDeckHost.Service.exe"" start= auto"; Flags: runhidden
Filename: "{sys}\sc.exe"; Parameters: "description TitanDeckHost ""Lets TitanDeck on the iPad check and fix Remote Desktop and send files."""; Flags: runhidden
Filename: "{sys}\sc.exe"; Parameters: "failure TitanDeckHost reset= 86400 actions= restart/5000/restart/5000/restart/30000"; Flags: runhidden
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""TitanDeck - Host"""; Flags: runhidden
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall add rule name=""TitanDeck - Host"" dir=in action=allow protocol=TCP localport=4431 profile=private,domain"; Flags: runhidden
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""TitanDeck - Host discovery"""; Flags: runhidden
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall add rule name=""TitanDeck - Host discovery"" dir=in action=allow protocol=UDP localport=5353 profile=private,domain"; Flags: runhidden
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""TitanDeck - Desk link"""; Flags: runhidden
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall add rule name=""TitanDeck - Desk link"" dir=in action=allow protocol=TCP localport=4434 profile=private,domain"; Flags: runhidden
; Fake Titan (4430 WebAPI, 4433 desk): only for the Host's own service, so it opens nothing for anything else.
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""TitanDeck - Fake Titan"""; Flags: runhidden
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall add rule name=""TitanDeck - Fake Titan"" dir=in action=allow protocol=TCP localport=4430,4433 program=""{app}\TitanDeckHost.Service.exe"" profile=private,domain"; Flags: runhidden
Filename: "{sys}\sc.exe"; Parameters: "start TitanDeckHost"; Flags: runhidden; StatusMsg: "Starting the service..."
Filename: "{app}\TitanDeckHost.exe"; Description: "Open TitanDeck Host"; Flags: postinstall nowait skipifsilent
; Updating from the Host window (/UPDATE=1, silent): open it again, as the signed-in user.
Filename: "{app}\TitanDeckHost.exe"; Flags: nowait runasoriginaluser; Check: IsUpdate

[UninstallRun]
Filename: "{sys}\taskkill.exe"; Parameters: "/F /IM TitanDeckHost.exe"; Flags: runhidden; RunOnceId: "KillTray"
Filename: "{sys}\sc.exe"; Parameters: "stop TitanDeckHost"; Flags: runhidden; RunOnceId: "StopService"
Filename: "{sys}\sc.exe"; Parameters: "delete TitanDeckHost"; Flags: runhidden; RunOnceId: "DeleteService"
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""TitanDeck - Host"""; Flags: runhidden; RunOnceId: "FwHost"
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""TitanDeck - Host discovery"""; Flags: runhidden; RunOnceId: "FwDiscovery"
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""TitanDeck - Desk link"""; Flags: runhidden; RunOnceId: "FwDeskLink"
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""TitanDeck - Fake Titan"""; Flags: runhidden; RunOnceId: "FwFakeTitan"

[Code]
// Started by the Host window's Update button.
function IsUpdate: Boolean;
begin
  Result := ExpandConstant('{param:UPDATE|0}') = '1';
end;

// Upgrades: stop the service and close the tray app before files are replaced.
function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  ResultCode: Integer;
begin
  Exec(ExpandConstant('{sys}\sc.exe'), 'stop TitanDeckHost', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Exec(ExpandConstant('{sys}\taskkill.exe'), '/F /IM TitanDeckHost.exe', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Sleep(2000);
  Result := '';
end;
