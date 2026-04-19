$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

if (-not (Test-Path ".venv")) {
    Write-Host "Erstelle virtuelles Environment..."
    python -m venv .venv
}

Write-Host "Installiere Paket..."
.\.venv\Scripts\pip install -e ".[dev]" --quiet

Write-Host "Baue Suchindex (inkrementell)..."
.\.venv\Scripts\dsa-rules-cli refresh

Write-Host "Setup abgeschlossen. MCP-Server bereit."
