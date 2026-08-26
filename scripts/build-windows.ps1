[CmdletBinding()]
param(
    [switch]$Installer,
    [switch]$SkipTests,
    [string]$OutputDirectory = "",
    [string]$Configuration = "release"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Set-WindowsGuiSubsystem {
    param([Parameter(Mandatory = $true)][string]$Path)

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -lt 256 -or $bytes[0] -ne 0x4d -or $bytes[1] -ne 0x5a) {
        throw "$Path is not a valid PE executable."
    }
    $peOffset = [BitConverter]::ToInt32($bytes, 0x3c)
    if ($peOffset -lt 0 -or $peOffset + 96 -ge $bytes.Length -or
        $bytes[$peOffset] -ne 0x50 -or $bytes[$peOffset + 1] -ne 0x45) {
        throw "$Path has an invalid PE header."
    }
    $optionalHeader = $peOffset + 24
    $magic = [BitConverter]::ToUInt16($bytes, $optionalHeader)
    if ($magic -ne 0x10b -and $magic -ne 0x20b) {
        throw "$Path has an unsupported PE optional-header format."
    }
    # The Subsystem field is at offset 68 in both PE32 and PE32+ optional
    # headers. Preserve the Swift-generated CRT entry point and change only the
    # distribution copy from console (3) to Windows GUI (2).
    $subsystemOffset = $optionalHeader + 68
    $guiSubsystem = [BitConverter]::GetBytes([UInt16]2)
    $bytes[$subsystemOffset] = $guiSubsystem[0]
    $bytes[$subsystemOffset + 1] = $guiSubsystem[1]
    [System.IO.File]::WriteAllBytes($Path, $bytes)
}

if ($env:OS -ne "Windows_NT") {
    throw "This script builds the native Windows target and must run on 64-bit Windows."
}

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $repositoryRoot "dist\windows"
} elseif (-not [System.IO.Path]::IsPathRooted($OutputDirectory)) {
    $OutputDirectory = Join-Path $repositoryRoot $OutputDirectory
}
$OutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
$stageDirectory = Join-Path $OutputDirectory "AutoTechno-Windows-x64"
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
Write-Host "Building Auto Techno with $swiftVersion"

Push-Location $repositoryRoot
try {
    if (-not $SkipTests) {
        & $swift.Source test --build-path $buildDirectory
        if ($LASTEXITCODE -ne 0) {
            throw "Swift tests failed. No distribution was produced."
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

    if (Test-Path $stageDirectory) {
        Remove-Item -LiteralPath $stageDirectory -Recurse -Force
    }
    New-Item -ItemType Directory -Path $stageDirectory -Force | Out-Null
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    Copy-Item -LiteralPath $executable -Destination $stageDirectory
    Set-WindowsGuiSubsystem -Path (Join-Path $stageDirectory "AutoTechno.exe")
    Copy-Item -LiteralPath (Join-Path $repositoryRoot "LICENSE") -Destination $stageDirectory
    Copy-Item -LiteralPath (Join-Path $repositoryRoot "packaging\windows\README.txt") -Destination $stageDirectory

    $targetInfo = (& $swiftc.Source -print-target-info | ConvertFrom-Json)
    $runtimePaths = @($targetInfo.paths.runtimeLibraryPaths) | Where-Object {
        -not [string]::IsNullOrWhiteSpace($_) -and (Test-Path $_ -PathType Container)
    }
    if ($runtimePaths.Count -eq 0) {
        throw "swiftc did not report a Windows runtime-library directory."
    }
    foreach ($runtimePath in $runtimePaths) {
        Get-ChildItem -LiteralPath $runtimePath -Filter "*.dll" -File | ForEach-Object {
            Copy-Item -LiteralPath $_.FullName -Destination $stageDirectory -Force
        }
    }

    $vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path $vswhere -PathType Leaf)) {
        throw "Unable to locate vswhere.exe for the redistributable MSVC runtime."
    }
    $visualStudioRoot = (& $vswhere -latest -products * `
        -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
        -property installationPath).Trim()
    if ([string]::IsNullOrWhiteSpace($visualStudioRoot)) {
        throw "Unable to locate a Visual Studio installation with the x64 C++ tools."
    }
    $msvcRedistRoot = Join-Path $visualStudioRoot "VC\Redist\MSVC"
    $msvcRuntime = Get-ChildItem -LiteralPath $msvcRedistRoot -Directory |
        Sort-Object Name -Descending |
        ForEach-Object { Join-Path $_.FullName "x64\Microsoft.VC143.CRT" } |
        Where-Object { Test-Path $_ -PathType Container } |
        Select-Object -First 1
    if ([string]::IsNullOrWhiteSpace($msvcRuntime)) {
        throw "Unable to locate the app-local x64 MSVC redistributable runtime."
    }
    Get-ChildItem -LiteralPath $msvcRuntime -Filter "*.dll" -File | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $stageDirectory -Force
    }

    $revision = (& git rev-parse --short=12 HEAD).Trim()
    if ($LASTEXITCODE -ne 0) {
        $revision = "unknown"
    }
    $dirtyStatus = (& git status --porcelain | Out-String).Trim()
    $dirty = -not [string]::IsNullOrWhiteSpace($dirtyStatus)
    $displayRevision = if ($dirty) { "$revision-dirty" } else { $revision }
    $manifest = [ordered]@{
        product = "AutoTechno"
        platform = "windows-x64"
        revision = $displayRevision
        configuration = $Configuration
        swift = $swiftVersion
        builtAtUtc = [DateTime]::UtcNow.ToString("o")
        runtimeBundled = $true
        msvcRuntimeBundled = $true
    }
    $manifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $stageDirectory "BUILD-MANIFEST.json") -Encoding utf8

    $checksums = Get-ChildItem -LiteralPath $stageDirectory -File | Sort-Object Name | ForEach-Object {
        $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        "$hash  $($_.Name)"
    }
    $checksums | Set-Content -LiteralPath (Join-Path $stageDirectory "CHECKSUMS.txt") -Encoding ascii

    $zipPath = Join-Path $OutputDirectory "AutoTechno-Windows-x64-$displayRevision.zip"
    if (Test-Path $zipPath) {
        Remove-Item -LiteralPath $zipPath -Force
    }
    Compress-Archive -Path (Join-Path $stageDirectory "*") -DestinationPath $zipPath -CompressionLevel Optimal
    Write-Host "Portable distribution: $zipPath"

    if ($Installer) {
        $innoCandidates = @(
            (Join-Path ${env:ProgramFiles(x86)} "Inno Setup 6\ISCC.exe"),
            (Join-Path $env:ProgramFiles "Inno Setup 6\ISCC.exe")
        ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        $iscc = $innoCandidates | Where-Object { Test-Path $_ -PathType Leaf } | Select-Object -First 1
        if ([string]::IsNullOrWhiteSpace($iscc)) {
            throw "The portable ZIP is complete, but Inno Setup is missing. Run scripts\setup-windows-build.cmd and retry for a one-file installer."
        }
        $installerScript = Join-Path $repositoryRoot "packaging\windows\AutoTechno.iss"
        & $iscc "/DSourceDir=$stageDirectory" "/DOutputDir=$OutputDirectory" "/DAppVersion=$displayRevision" $installerScript
        if ($LASTEXITCODE -ne 0) {
            throw "Inno Setup failed. The portable ZIP remains available at $zipPath."
        }
        $installerPath = Join-Path $OutputDirectory "AutoTechno-Windows-x64-Setup.exe"
        if (-not (Test-Path $installerPath -PathType Leaf)) {
            throw "Inno Setup completed without producing $installerPath."
        }
        $installerHash = (Get-FileHash -LiteralPath $installerPath -Algorithm SHA256).Hash.ToLowerInvariant()
        "$installerHash  $([System.IO.Path]::GetFileName($installerPath))" |
            Set-Content -LiteralPath (Join-Path $OutputDirectory "AutoTechno-Windows-x64-Setup.exe.sha256") -Encoding ascii
        Write-Host "One-file installer: $installerPath"
    }
} finally {
    Pop-Location
}
