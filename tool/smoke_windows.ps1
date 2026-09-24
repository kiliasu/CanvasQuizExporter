param(
    [string]$Executable = "$PSScriptRoot/../build/windows/x64/runner/Release/CanvasQuizExporter.exe",
    [string]$Report = "$PSScriptRoot/../build/validation/smoke.json",
    [string[]]$Inputs = @()
)
$ErrorActionPreference = 'Stop'
$executablePath = (Resolve-Path -LiteralPath $Executable).Path
$reportPath = [IO.Path]::GetFullPath($Report)
New-Item -ItemType Directory -Path (Split-Path $reportPath -Parent) -Force | Out-Null
if (Test-Path -LiteralPath $reportPath) { Remove-Item -LiteralPath $reportPath -Force }
$start = [Diagnostics.ProcessStartInfo]::new()
$start.FileName = $executablePath
$start.UseShellExecute = $false
$start.CreateNoWindow = $true
$start.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
$start.WorkingDirectory = Split-Path $reportPath -Parent
$start.Arguments = '--self-test "' + $reportPath + '"' + (($Inputs | ForEach-Object { ' "' + [IO.Path]::GetFullPath($_) + '"' }) -join '')
$start.EnvironmentVariables['PATH'] = "$env:SystemRoot\System32;$env:SystemRoot"
foreach ($name in @('PYTHONPATH', 'PYTHONHOME', 'QT_PLUGIN_PATH', 'QT_QPA_PLATFORM', 'QML2_IMPORT_PATH', 'FLUTTER_ROOT')) {
    $start.EnvironmentVariables.Remove($name)
}
$watch = [Diagnostics.Stopwatch]::StartNew()
$process = [Diagnostics.Process]::Start($start)
if (-not $process.WaitForExit(120000)) {
    $process.Kill()
    throw 'Application self-test timed out.'
}
if (-not (Test-Path -LiteralPath $reportPath)) { throw "No self-test report. Exit: $($process.ExitCode)" }
$result = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
if ($process.ExitCode -ne 0 -or $result.status -ne 'passed') { throw "Self-test failed (exit $($process.ExitCode)): $($result | ConvertTo-Json -Depth 8)" }
Write-Output "Self-test passed: $($result.exported_files) exports, $($result.pdfs.Count) PDFs rendered, process to first frame $($result.process_first_frame_ms) ms, total process $($watch.ElapsedMilliseconds) ms."
