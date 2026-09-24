param([string]$Flutter = 'flutter')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Push-Location $root
try {
    $resolution = & $Flutter pub get 2>&1
    $resolution | Write-Output
    if ($LASTEXITCODE -ne 0) {
        if (($resolution -join "`n") -notmatch 'symlink support' -or -not (Test-Path '.flutter-plugins-dependencies')) {
            throw 'Dependency resolution failed.'
        }
    }
    # NTFS junctions work without Developer Mode and Flutter accepts existing
    # links. This changes only generated project files, never OS settings.
    $metadata = Get-Content '.flutter-plugins-dependencies' -Raw | ConvertFrom-Json
    $links = Join-Path $root 'windows/flutter/ephemeral/.plugin_symlinks'
    New-Item -ItemType Directory -Path $links -Force | Out-Null
    foreach ($plugin in $metadata.plugins.windows) {
        $link = Join-Path $links $plugin.name
        if (-not (Test-Path -LiteralPath $link)) {
            New-Item -ItemType Junction -Path $link -Target $plugin.path | Out-Null
        }
    }
    if (-not (Test-Path '.dart_tool/package_config.json')) { throw 'Package configuration is missing.' }
} finally { Pop-Location }
