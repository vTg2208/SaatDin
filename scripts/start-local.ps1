param(
    [switch]$BackendOnly,
    [switch]$FrontendOnly,
    [switch]$BillingOnly
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent

function Start-Backend {
    Set-Location $repoRoot
    python -m uvicorn backend.app.main:app --host 127.0.0.1 --port 8000
}

function Start-Billing {
    Set-Location (Join-Path $repoRoot 'billing-service')
    .\mvnw.cmd spring-boot:run
}

function Start-Frontend {
    Set-Location $repoRoot
    flutter run
}

if (@($BackendOnly, $FrontendOnly, $BillingOnly).Where({ $_ }).Count -gt 1) {
    throw 'Choose only one of -BackendOnly, -FrontendOnly, or -BillingOnly.'
}

if ($BackendOnly) {
    Start-Backend
    exit 0
}

if ($FrontendOnly) {
    Start-Frontend
    exit 0
}

if ($BillingOnly) {
    Start-Billing
    exit 0
}

Write-Host 'Starting billing service on http://127.0.0.1:8082 ...'
$billingJob = Start-Job -ScriptBlock {
    param($cwd)
    Set-Location (Join-Path $cwd 'billing-service')
    .\mvnw.cmd spring-boot:run
} -ArgumentList $repoRoot

Start-Sleep -Seconds 5

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
    Stop-Job $billingJob -ErrorAction SilentlyContinue | Out-Null
    Remove-Job $billingJob -ErrorAction SilentlyContinue | Out-Null
}
