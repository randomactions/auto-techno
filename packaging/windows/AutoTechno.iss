#ifndef SourceDir
  #error SourceDir must point at the staged Windows distribution.
#endif
#ifndef OutputDir
  #error OutputDir must point at the distribution output directory.
#endif
#ifndef AppVersion
  #define AppVersion "development"
#endif

[Setup]
AppId={{D2ED16D8-01A0-4A14-963C-D34BA2A8247C}
AppName=Auto Techno
AppVersion={#AppVersion}
AppPublisher=Auto Techno
DefaultDirName={localappdata}\Programs\Auto Techno
DefaultGroupName=Auto Techno
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir={#OutputDir}
OutputBaseFilename=AutoTechno-Windows-x64-Setup
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\AutoTechno.exe
SetupLogging=yes

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Auto Techno"; Filename: "{app}\AutoTechno.exe"; WorkingDir: "{app}"

[Run]
Filename: "{app}\AutoTechno.exe"; Description: "Launch Auto Techno"; Flags: nowait postinstall skipifsilent
