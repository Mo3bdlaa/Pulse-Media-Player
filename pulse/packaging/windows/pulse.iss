; Pulse — Windows installer (Inno Setup 6).
; Built by pulse/tools/package-windows.sh:
;   iscc /DAppVersion=<version> /DSourceDir=<staged app> /DOutputDir=<dir> pulse.iss

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

[Setup]
AppId={{6F1C2B9E-4D7A-4E59-9C1E-50A1B2C3D4E5}
AppName=Pulse
AppVersion={#AppVersion}
AppVerName=Pulse {#AppVersion}
AppPublisher=Pulse
AppComments=Play anything. Feel more.
DefaultDirName={autopf}\Pulse
DefaultGroupName=Pulse
DisableProgramGroupPage=yes
; Installs for the current user without asking for administrator rights;
; the first page offers installing for everyone instead.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
OutputDir={#OutputDir}
OutputBaseFilename=Pulse-{#AppVersion}-win64-setup
SetupIconFile=pulse.ico
UninstallDisplayIcon={app}\pulse.exe
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Pulse"; Filename: "{app}\pulse.exe"
Name: "{autodesktop}\Pulse"; Filename: "{app}\pulse.exe"; Tasks: desktopicon

[Registry]
; "Open with Pulse" for media files, without taking over any file type.
Root: HKA; Subkey: "Software\Classes\Applications\pulse.exe"; ValueType: string; ValueName: "FriendlyAppName"; ValueData: "Pulse"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\Applications\pulse.exe\DefaultIcon"; ValueType: string; ValueData: "{app}\pulse.exe,0"
Root: HKA; Subkey: "Software\Classes\Applications\pulse.exe\shell\open\command"; ValueType: string; ValueData: """{app}\pulse.exe"" ""%1"""
Root: HKA; Subkey: "Software\Classes\.mp4\OpenWithList\pulse.exe"; ValueType: none; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\.mkv\OpenWithList\pulse.exe"; ValueType: none; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\.avi\OpenWithList\pulse.exe"; ValueType: none; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\.mov\OpenWithList\pulse.exe"; ValueType: none; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\.webm\OpenWithList\pulse.exe"; ValueType: none; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\.wmv\OpenWithList\pulse.exe"; ValueType: none; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\.m4v\OpenWithList\pulse.exe"; ValueType: none; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\.mpg\OpenWithList\pulse.exe"; ValueType: none; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\.mpeg\OpenWithList\pulse.exe"; ValueType: none; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\.ts\OpenWithList\pulse.exe"; ValueType: none; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\.flv\OpenWithList\pulse.exe"; ValueType: none; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\.mp3\OpenWithList\pulse.exe"; ValueType: none; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\.flac\OpenWithList\pulse.exe"; ValueType: none; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\.m4a\OpenWithList\pulse.exe"; ValueType: none; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\.aac\OpenWithList\pulse.exe"; ValueType: none; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\.ogg\OpenWithList\pulse.exe"; ValueType: none; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\.opus\OpenWithList\pulse.exe"; ValueType: none; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\.wav\OpenWithList\pulse.exe"; ValueType: none; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\.wma\OpenWithList\pulse.exe"; ValueType: none; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\.m3u\OpenWithList\pulse.exe"; ValueType: none; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\.m3u8\OpenWithList\pulse.exe"; ValueType: none; Flags: uninsdeletekey

[Run]
Filename: "{app}\pulse.exe"; Description: "{cm:LaunchProgram,Pulse}"; Flags: nowait postinstall skipifsilent
