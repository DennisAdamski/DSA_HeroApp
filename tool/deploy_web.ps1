param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('test', 'production')]
    [string]$Target,
    [string]$AppCheckSiteKey = $env:FIREBASE_APP_CHECK_SITE_KEY,
    [string]$LegalResponsibleName = $env:LEGAL_RESPONSIBLE_NAME,
    [string]$LegalStreetAddress = $env:LEGAL_STREET_ADDRESS,
    [string]$LegalPostalCode = $env:LEGAL_POSTAL_CODE,
    [string]$LegalCity = $env:LEGAL_CITY,
    [string]$LegalCountry = $env:LEGAL_COUNTRY,
    [string]$LegalContactEmail = $env:LEGAL_CONTACT_EMAIL
)

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

if ([string]::IsNullOrWhiteSpace($AppCheckSiteKey)) {
    throw 'FIREBASE_APP_CHECK_SITE_KEY fehlt. Release-Deploy abgebrochen.'
}

$legalValues = @{
    LEGAL_RESPONSIBLE_NAME = $LegalResponsibleName
    LEGAL_STREET_ADDRESS = $LegalStreetAddress
    LEGAL_POSTAL_CODE = $LegalPostalCode
    LEGAL_CITY = $LegalCity
    LEGAL_COUNTRY = $LegalCountry
    LEGAL_CONTACT_EMAIL = $LegalContactEmail
}
foreach ($entry in $legalValues.GetEnumerator()) {
    if ([string]::IsNullOrWhiteSpace($entry.Value)) {
        throw "$($entry.Key) fehlt. Release-Deploy abgebrochen."
    }
}

$feedbackApiUrls = @{
    test = 'https://europe-west10-heldensync-ccf0b.cloudfunctions.net/feedbackApiTest'
    production = 'https://europe-west10-heldensync-ccf0b.cloudfunctions.net/feedbackApi'
}
$feedbackApiUrl = $feedbackApiUrls[$Target]

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
    "--dart-define=BUILD_TIME=$buildTime" `
    "--dart-define=FEEDBACK_API_URL=$feedbackApiUrl" `
    "--dart-define=FIREBASE_APP_CHECK_SITE_KEY=$AppCheckSiteKey" `
    "--dart-define=LEGAL_RESPONSIBLE_NAME=$LegalResponsibleName" `
    "--dart-define=LEGAL_STREET_ADDRESS=$LegalStreetAddress" `
    "--dart-define=LEGAL_POSTAL_CODE=$LegalPostalCode" `
    "--dart-define=LEGAL_CITY=$LegalCity" `
    "--dart-define=LEGAL_COUNTRY=$LegalCountry" `
    "--dart-define=LEGAL_CONTACT_EMAIL=$LegalContactEmail"

$manifest = 'build/web/assets/AssetManifest.bin.json'
if (-not (Test-Path $manifest)) {
    throw "Build kaputt: $manifest fehlt. Asset-Phase wurde uebersprungen (vermutlich AV-Interferenz). Erneut bauen oder AV pausieren."
}

$heroes = Get-ChildItem 'build/web/assets/assets/heroes' -File -ErrorAction SilentlyContinue
if (-not $heroes) {
    throw 'Build kaputt: build/web/assets/assets/heroes ist leer. Erneut bauen.'
}

# firebase-tools liest ältere CRLF-Hashcaches unter Windows teilweise mit einem
# angehängten Carriage Return ein. Der Server liefert denselben Hash normalisiert
# zurück und der Upload kann die zugehörige Datei dann nicht mehr auflösen.
$hostingHashCache = Join-Path (Get-Location) '.firebase/hosting.YnVpbGRcd2Vi.cache'
if (Test-Path -LiteralPath $hostingHashCache) {
    Write-Host '== veralteten Firebase-Hosting-Hashcache entfernen =='
    Remove-Item -LiteralPath $hostingHashCache
}

Write-Host "== firebase deploy --only hosting:$Target =="
firebase deploy --only "hosting:$Target"
