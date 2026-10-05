# Web-Deploy fuer DSA-Heldenverwaltung.
#
# Auf diesem Windows-Setup verlieren inkrementelle Flutter-Web-Builds
# regelmaessig den Asset-Ordner (vermutlich AV-Interferenz, siehe
# docs/windows_antivirus_audit.md). Das fuehrt zu leerem
# build/web/assets/ ohne AssetManifest.json — die deployte App
# startet dann mit einem "FormatException: Unexpected token '<'"-Fehler,
# weil Firebase Hosting auf fehlende Assets via SPA-Rewrite mit der
# index.html antwortet.
#
# Daher immer: clean -> pub get -> build -> assert -> deploy.

$ErrorActionPreference = 'Stop'
Set-Location -Path (Split-Path -Parent $PSScriptRoot)

Write-Host '== flutter clean =='
flutter clean

Write-Host '== flutter pub get =='
flutter pub get

Write-Host '== flutter build web --release =='
# Commit und Bauzeit erscheinen in der App unter Einstellungen.
$commit = git rev-parse HEAD
if (git status --porcelain) { $commit = "$commit-dirty" }
$buildTime = [DateTime]::UtcNow.ToString(
    "yyyy-MM-dd'T'HH:mm:ss'Z'",
    [Globalization.CultureInfo]::InvariantCulture)
flutter build web --release --no-wasm-dry-run `
    "--dart-define=BUILD_COMMIT=$commit" `
    "--dart-define=BUILD_TIME=$buildTime"

$manifest = 'build/web/assets/AssetManifest.bin.json'
if (-not (Test-Path $manifest)) {
    throw "Build kaputt: $manifest fehlt. Asset-Phase wurde uebersprungen (vermutlich AV-Interferenz). Erneut bauen oder AV pausieren."
}

$heroes = Get-ChildItem 'build/web/assets/assets/heroes' -File -ErrorAction SilentlyContinue
if (-not $heroes) {
    throw 'Build kaputt: build/web/assets/assets/heroes ist leer. Erneut bauen.'
}

Write-Host '== firebase deploy --only hosting =='
firebase deploy --only hosting
