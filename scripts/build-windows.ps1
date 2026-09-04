[CmdletBinding()]
param(
    [switch]$SkipTests,
    [string]$Configuration = "release"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if ($env:OS -ne "Windows_NT") {
    throw "This script validates the native Windows target and must run on 64-bit Windows."
}

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$buildDirectory = Join-Path $repositoryRoot ".build-windows"
$swift = Get-Command swift -ErrorAction SilentlyContinue
$swiftc = Get-Command swiftc -ErrorAction SilentlyContinue
if ($null -eq $swift -or $null -eq $swiftc) {
    throw "Swift is not available. Run scripts\setup-windows-build.cmd once, reopen PowerShell, and retry."
}

$swiftVersion = (& $swift.Source --version | Select-Object -First 1).Trim()
if ($LASTEXITCODE -ne 0) {
    throw "Unable to run the installed Swift toolchain."
}
Write-Host "Validating Auto Techno source with $swiftVersion"

Push-Location $repositoryRoot
try {
    if (-not $SkipTests) {
        & $swift.Source test --build-path $buildDirectory
        if ($LASTEXITCODE -ne 0) {
            throw "Swift tests failed."
        }
    }

    & $swift.Source build -c $Configuration --product AutoTechno --build-path $buildDirectory
    if ($LASTEXITCODE -ne 0) {
        throw "The Windows release build failed."
    }

    $binaryDirectory = (& $swift.Source build -c $Configuration --show-bin-path --build-path $buildDirectory).Trim()
    $executable = Join-Path $binaryDirectory "AutoTechno.exe"
    if (-not (Test-Path $executable -PathType Leaf)) {
        throw "The build completed without producing $executable."
    }

    Write-Host "Windows source validation complete: $executable"
    Write-Host "No portable archive or installer was produced. Distribution remains isolated until runtime-file licence and REDIST provenance are implemented and verified."
} finally {
    Pop-Location
}
