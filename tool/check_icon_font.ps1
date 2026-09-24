param(
    [Parameter(Mandatory = $true)][string]$ExpectedFont,
    [string]$Assets = "$PSScriptRoot/../build/windows/x64/runner/Release/data/flutter_assets"
)
$ErrorActionPreference = 'Stop'
$manifest = Get-Content -LiteralPath (Join-Path $Assets 'FontManifest.json') -Raw | ConvertFrom-Json
$family = @($manifest | Where-Object { $_.family -eq 'Material Symbols Rounded' })
if ($family.Count -ne 1 -or $family[0].fonts.Count -ne 1) {
    throw 'Release FontManifest must contain the Material Symbols Rounded font.'
}
$asset = $family[0].fonts[0].asset
$font = Get-Item -LiteralPath (Join-Path $Assets $asset)
$expectedHash = (Get-FileHash -LiteralPath $ExpectedFont -Algorithm SHA256).Hash
$actualHash = (Get-FileHash -LiteralPath $font.FullName -Algorithm SHA256).Hash
if ($actualHash -ne $expectedHash) {
    throw 'Release icon font is incomplete or stale. Rebuild with tool/build_windows.ps1 (--no-tree-shake-icons).'
}
[ordered]@{
    status = 'passed'
    family = 'Material Symbols Rounded'
    asset = $asset
    bytes = $font.Length
    sha256 = $actualHash.ToLowerInvariant()
} | ConvertTo-Json
