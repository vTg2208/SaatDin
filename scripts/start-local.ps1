param(
    [switch]$BackendOnly,
    [switch]$FrontendOnly
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent

function Start-Backend {
    Set-Location $repoRoot
    python -m uvicorn backend.app.main:app --host 127.0.0.1 --port 8000
}

function Start-Frontend {
    Set-Location $repoRoot
    flutter run
}

if ($BackendOnly -and $FrontendOnly) {
    throw 'Choose either -BackendOnly or -FrontendOnly, not both.'
}

if ($BackendOnly) {
    Start-Backend
    exit 0
}

if ($FrontendOnly) {
    Start-Frontend
    exit 0
}

Write-Host 'Starting SaatDin backend on http://127.0.0.1:8000 ...'
$backendJob = Start-Job -ScriptBlock {
    param($cwd)
    Set-Location $cwd
    python -m uvicorn backend.app.main:app --host 127.0.0.1 --port 8000
} -ArgumentList $repoRoot

Start-Sleep -Seconds 3

try {
    Write-Host 'Starting Flutter app...'
    Start-Frontend
} finally {
    Stop-Job $backendJob -ErrorAction SilentlyContinue | Out-Null
    Remove-Job $backendJob -ErrorAction SilentlyContinue | Out-Null
}
