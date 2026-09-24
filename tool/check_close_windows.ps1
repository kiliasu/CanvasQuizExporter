param(
    [string]$Executable = "$PSScriptRoot/../build/windows/x64/runner/Release/CanvasQuizExporter.exe",
    [string]$ReportDirectory = "$PSScriptRoot/../build/validation/close",
    [string[]]$Modes = @('idle', 'export', 'pdf'),
    [int]$TimeoutSeconds = 20
)
$ErrorActionPreference = 'Stop'
$executablePath = (Resolve-Path -LiteralPath $Executable).Path
$reportRoot = [IO.Path]::GetFullPath($ReportDirectory)
foreach ($mode in $Modes) {
    $reportPath = Join-Path $reportRoot "$mode/report.json"
    New-Item -ItemType Directory -Path (Split-Path $reportPath -Parent) -Force | Out-Null
    if (Test-Path -LiteralPath $reportPath) { Remove-Item -LiteralPath $reportPath -Force }
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $executablePath
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    $start.WorkingDirectory = Split-Path $reportPath -Parent
    $start.Arguments = '--close-test "' + $reportPath + '" ' + $mode
    $start.EnvironmentVariables['PATH'] = "$env:SystemRoot\System32;$env:SystemRoot"
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $process = [Diagnostics.Process]::Start($start)
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        $process.Kill()
        $process.WaitForExit()
        throw "Close test $mode timed out after $TimeoutSeconds seconds; the app process did not exit."
    }
    if (-not (Test-Path -LiteralPath $reportPath)) { throw "Close test $mode produced no report. Exit: $($process.ExitCode)" }
    $result = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
    if ($process.ExitCode -ne 0 -or $result.status -ne 'ready-to-close' -or $result.busy -or -not $result.saved_settings -or $result.framework_errors.Count -ne 0) {
        throw "Close test $mode failed (exit $($process.ExitCode)): $($result | ConvertTo-Json -Depth 8)"
    }
    if ($mode -eq 'export' -and ($result.confirmations -ne 1 -or $result.completed_inputs -ne 1 -or $result.exported_files -ne 5)) {
        throw "Export close test did not finish exactly the active input: $($result | ConvertTo-Json -Depth 8)"
    }
    if ($mode -eq 'pdf' -and ($result.pdf_preview.pages -lt 1 -or $result.pdf_preview.pixel_width -lt 1 -or $result.pdf_preview.pixel_height -lt 1)) {
        throw "PDF close test did not confirm a loaded and rendered preview: $($result | ConvertTo-Json -Depth 8)"
    }
    $result.status = 'passed'
    $result | Add-Member -NotePropertyName process_exit_code -NotePropertyValue $process.ExitCode
    $result | Add-Member -NotePropertyName total_process_ms -NotePropertyValue $watch.ElapsedMilliseconds
    $closeMilliseconds = [DateTimeOffset]::new($process.ExitTime).ToUnixTimeMilliseconds() - [long]$result.close_requested_ms
    $result | Add-Member -NotePropertyName close_to_exit_ms -NotePropertyValue $closeMilliseconds
    $result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $reportPath -Encoding utf8
    Write-Output "Close test $mode passed: actual process exit in $closeMilliseconds ms after native close."
}
