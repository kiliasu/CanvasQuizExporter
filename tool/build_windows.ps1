param([string]$Flutter = 'flutter', [switch]$SkipTests)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$flutterCommand = (Get-Command $Flutter -ErrorAction Stop).Source
$sdk = Split-Path (Split-Path $flutterCommand -Parent) -Parent
$dart = Join-Path $sdk 'bin/dart.bat'
Push-Location $root
try {
    & "$PSScriptRoot/prepare_windows.ps1" -Flutter $flutterCommand
    if (-not $SkipTests) {
        & $dart format --output=none --set-exit-if-changed lib test tool
        if ($LASTEXITCODE -ne 0) { throw 'Run dart format before building.' }
        & $flutterCommand analyze --no-pub
        if ($LASTEXITCODE -ne 0) { throw 'Analyzer failed.' }
        & $flutterCommand test --no-pub
        if ($LASTEXITCODE -ne 0) { throw 'Tests failed.' }
    }
    # Flutter 3.47 Windows asset caching can retain an old icon subset after
    # Dart-only changes. Keep the complete icon font and verify the built asset.
    & $flutterCommand build windows --release --no-pub --no-tree-shake-icons
    if ($LASTEXITCODE -ne 0) { throw 'Windows build failed.' }
    $releaseDirectory = Join-Path $root 'build/windows/x64/runner/Release'
    foreach ($notice in 'LICENSE', 'THIRD_PARTY_NOTICES.md', 'licenses/pdfium-LICENSE.txt') {
        if (-not (Test-Path -LiteralPath (Join-Path $releaseDirectory $notice))) { throw "Release output is missing $notice." }
    }
    $releaseAssets = Join-Path $releaseDirectory 'data/flutter_assets'
    $reports = Join-Path $root 'build/validation'
    # The probes never overwrite exports, so start each run with empty reports.
    if (Test-Path -LiteralPath $reports) { Remove-Item -LiteralPath $reports -Recurse -Force }
    New-Item -ItemType Directory -Path $reports -Force | Out-Null
    $materialFont = Join-Path $root 'assets/fonts/material-symbols-rounded.ttf'
    & "$PSScriptRoot/check_icon_font.ps1" -ExpectedFont $materialFont -Assets $releaseAssets | Set-Content -LiteralPath (Join-Path $reports 'icon-font.json') -Encoding utf8
    & $flutterCommand test --no-pub "--dart-define=PREVIEW_ASSETS=$releaseAssets" tool/render_preview_test.dart
    if ($LASTEXITCODE -ne 0) { throw 'Built asset preview failed.' }
    $executable = Join-Path $releaseDirectory 'CanvasQuizExporter.exe'
    & "$PSScriptRoot/smoke_windows.ps1" -Executable $executable -Report (Join-Path $reports 'smoke.json')
    & "$PSScriptRoot/check_close_windows.ps1" -Executable $executable -ReportDirectory (Join-Path $reports 'close')
    Write-Output 'Windows build verified. Output: build/windows/x64/runner/Release; reports: build/validation.'
} finally { Pop-Location }
