[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if ($env:OS -ne "Windows_NT") {
    throw "This setup script must run on 64-bit Windows."
}
if ($null -eq (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw "Windows Package Manager (winget) is required. Install App Installer from Microsoft and retry."
}

Write-Host "Installing the official Windows compiler/SDK prerequisites..."
winget install --id Microsoft.VisualStudio.2022.Community --exact --force `
    --custom "--add Microsoft.VisualStudio.Component.Windows11SDK.22621 --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64" `
    --source winget --accept-package-agreements --accept-source-agreements
if ($LASTEXITCODE -ne 0) { throw "Visual Studio prerequisite installation failed." }

Write-Host "Installing the official Swift toolchain..."
winget install --id Swift.Toolchain --exact --version 6.3.3 --source winget `
    --accept-package-agreements --accept-source-agreements
if ($LASTEXITCODE -ne 0) { throw "Swift toolchain installation failed." }

Write-Host "Installing Inno Setup for the one-file installer..."
winget install --id JRSoftware.InnoSetup --exact --source winget `
    --accept-package-agreements --accept-source-agreements
if ($LASTEXITCODE -ne 0) { throw "Inno Setup installation failed." }

Write-Host "Setup complete. Close this window, reopen PowerShell, then run scripts\build-windows.cmd."
