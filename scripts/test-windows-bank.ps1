[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateRange(0, 31)][int]$Bank,
    [ValidateRange(1, 32)][int]$Banks = 8
)
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
if ($env:OS -ne "Windows_NT") { throw "Native Windows execution is required." }
if ($Bank -ge $Banks) { throw "Invalid bank index." }
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Push-Location $repositoryRoot
try {
    foreach ($library in @("xctest", "swift-testing")) {
        $arguments = if ($library -eq "xctest") {
            @("--enable-xctest", "--disable-swift-testing")
        } else { @("--disable-xctest", "--enable-swift-testing") }
        # Keep compiler/progress stderr separate from the strict identifier file.
        swift test --build-path .build-windows list --skip-build @arguments |
            Out-File -Encoding utf8 "windows-discovery-$library.txt"
        if ($LASTEXITCODE -ne 0) { throw "Discovery failed for $library." }
    }
    python scripts/windows_test_plan.py --xctest windows-discovery-xctest.txt --swift-testing windows-discovery-swift-testing.txt --bank $Bank --banks $Banks --output windows-bank-plan.json
    if ($LASTEXITCODE -ne 0) { throw "Native bank planning failed." }
    $plan = Get-Content -Raw windows-bank-plan.json | ConvertFrom-Json
    $results = @()
    foreach ($suite in $plan.selected) {
        Write-Host "BEGIN native suite $($suite.library):$($suite.suite), bank $Bank/$Banks"
        $arguments = if ($suite.library -eq "xctest") {
            @("--enable-xctest", "--disable-swift-testing")
        } else { @("--disable-xctest", "--enable-swift-testing") }
        $log = "windows-$Bank-$($suite.library)-$($suite.suite).log"
        swift test --build-path .build-windows --skip-build --no-parallel @arguments --filter $suite.selector 2>&1 |
            Tee-Object -FilePath $log
        $testExit = $LASTEXITCODE
        if ($testExit -ne 0) { throw "Native suite $($suite.suite) failed with exit $testExit." }
        $summary = if ($suite.library -eq "xctest") {
            'Executed ([0-9]+) tests?, with 0 failures'
        } else { 'Test run with ([0-9]+) tests? passed' }
        $completionLines = @(Select-String -Path $log -Pattern $summary)
        if ($completionLines.Count -eq 0) { throw "Missing native completion summary for $($suite.suite)." }
        $count = [int]$completionLines[-1].Matches[0].Groups[1].Value
        if ($count -eq 0 -and -not (Select-String -Path $log -Pattern 'skipped' -Quiet)) {
            throw "No tests executed or explicitly skipped for $($suite.suite)."
        }
        $results += [ordered]@{
            library = $suite.library; suite = $suite.suite
            discovered = @($suite.identifiers).Count; reportedTests = $count
            logSHA256 = (Get-FileHash -Algorithm SHA256 $log).Hash.ToLowerInvariant()
            exitCode = $testExit
        }
        Write-Host "END native suite $($suite.library):$($suite.suite)"
    }
    [ordered]@{
        schema = "autotechno-windows-test-bank-result.v1"
        source = (git rev-parse HEAD).Trim(); bank = $Bank; banks = $Banks
        discoverySHA256 = $plan.discoverySHA256
        discoveredIdentifiers = $plan.discoveredIdentifiers
        completedSuites = $results
        fullWindowsQualification = $false
    } | ConvertTo-Json -Depth 8 -Compress | Write-Output
} finally { Pop-Location }
