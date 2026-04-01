param(
    [string]$BaseUrl = "http://127.0.0.1:8000/api/v1",
    [string]$Phone = "9876501234"
)

$ErrorActionPreference = "Stop"

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )
    if (-not $Condition) {
        throw "ASSERT FAILED: $Message"
    }
}

try {
    Write-Host "[1/9] Sending OTP..."
    $send = Invoke-RestMethod -Uri "$BaseUrl/auth/send-otp" -Method Post -ContentType "application/json" -Body (@{ phoneNumber = $Phone } | ConvertTo-Json)
    Assert-True ($send.success -eq $true) "send-otp must return success=true"

    $otp = $send.data.debugOtp
    Assert-True (-not [string]::IsNullOrWhiteSpace($otp)) "debugOtp missing. Set EXPOSE_DEBUG_OTP=true for integration tests"

    Write-Host "[2/9] Verifying OTP..."
    $verify = Invoke-RestMethod -Uri "$BaseUrl/auth/verify-otp" -Method Post -ContentType "application/json" -Body (@{ phoneNumber = $Phone; otp = $otp } | ConvertTo-Json)
    Assert-True ($verify.success -eq $true) "verify-otp must return success=true"

    $token = $verify.data.token
    Assert-True (-not [string]::IsNullOrWhiteSpace($token)) "JWT token missing from verify response"
    $headers = @{ Authorization = "Bearer $token" }

    Write-Host "[3/9] Fetching platforms..."
    $platforms = Invoke-RestMethod -Uri "$BaseUrl/platforms" -Headers $headers -Method Get
    Assert-True ($platforms.success -eq $true) "platforms endpoint must return success=true"
    Assert-True ($platforms.data.Count -gt 0) "platforms list is empty"

    Write-Host "[4/9] Fetching zones for Blinkit..."
    $zones = Invoke-RestMethod -Uri "$BaseUrl/zones?platform=Blinkit" -Headers $headers -Method Get
    Assert-True ($zones.success -eq $true) "zones endpoint must return success=true"
    Assert-True ($zones.data.Count -gt 0) "zones list is empty"
    $firstZone = $zones.data[0]

    Write-Host "[5/9] Fetching plans for zone $($firstZone.pincode)..."
    $plans = Invoke-RestMethod -Uri "$BaseUrl/plans?zone=$($firstZone.pincode)&platform=Blinkit" -Headers $headers -Method Get
    Assert-True ($plans.success -eq $true) "plans endpoint must return success=true"
    Assert-True ($plans.data.Count -gt 0) "plans list is empty"
    $firstPlan = $plans.data[0]

    Write-Host "[6/9] Registering worker..."
    $registerBody = @{
        phone = $Phone
        platformName = "Blinkit"
        zone = $firstZone.pincode
        planName = $firstPlan.name
        name = "Integration Tester"
    } | ConvertTo-Json

    $register = Invoke-RestMethod -Uri "$BaseUrl/register" -Headers $headers -Method Post -ContentType "application/json" -Body $registerBody
    Assert-True ($register.success -eq $true) "register endpoint must return success=true"

    Write-Host "[7/9] Fetching worker profile..."
    $me = Invoke-RestMethod -Uri "$BaseUrl/workers/me" -Headers $headers -Method Get
    Assert-True ($me.success -eq $true) "workers/me endpoint must return success=true"
    Assert-True ($me.data.phone -eq $Phone) "workers/me returned unexpected phone"

    Write-Host "[8/11] Fetching policy..."
    $policy = Invoke-RestMethod -Uri "$BaseUrl/policy/me" -Headers $headers -Method Get
    Assert-True ($policy.success -eq $true) "policy/me endpoint must return success=true"
    Assert-True (-not [string]::IsNullOrWhiteSpace($policy.data.plan)) "policy plan missing"

    Write-Host "[9/12] Updating policy plan..."
    $updatedPolicy = Invoke-RestMethod -Uri "$BaseUrl/policy/plan" -Headers $headers -Method Put -ContentType "application/json" -Body (@{ planName = "Premium" } | ConvertTo-Json)
    Assert-True ($updatedPolicy.success -eq $true) "policy/plan endpoint must return success=true"
    Assert-True ($updatedPolicy.data.plan -eq "Premium") "policy plan update did not persist"

    Write-Host "[10/12] Submitting manual claim..."
    $manualClaimBody = @{ claimType = "TrafficBlock"; description = "Road blocked due to severe congestion" } | ConvertTo-Json
    $manualClaim = Invoke-RestMethod -Uri "$BaseUrl/claims/submit" -Headers $headers -Method Post -ContentType "application/json" -Body $manualClaimBody
    Assert-True ($manualClaim.success -eq $true) "claims/submit endpoint must return success=true"

    Write-Host "[11/12] Fetching claims list..."
    $claims = Invoke-RestMethod -Uri "$BaseUrl/claims" -Headers $headers -Method Get
    Assert-True ($claims.success -eq $true) "claims endpoint must return success=true"
    Assert-True ($claims.data.Count -gt 0) "claims list is empty"

    Write-Host "[12/12] Fetching active triggers..."
    $triggers = Invoke-RestMethod -Uri "$BaseUrl/triggers/active?zone=$($firstZone.pincode)" -Headers $headers -Method Get
    Assert-True ($triggers.success -eq $true) "triggers/active endpoint must return success=true"

    Write-Host "[final] Health check..."
    $health = Invoke-RestMethod -Uri "$BaseUrl/health" -Method Get
    Assert-True ($health.status -eq "ok" -or $health.status -eq "degraded") "health status invalid"

    $summary = [ordered]@{
        sendOtp = $send.success
        verifyOtp = $verify.success
        platformsCount = $platforms.data.Count
        zonesCount = $zones.data.Count
        plansCount = $plans.data.Count
        registerSuccess = $register.success
        workerPhone = $me.data.phone
        policyPlan = $policy.data.plan
        claimsCount = $claims.data.Count
        triggerSource = $triggers.data.source
        healthStatus = $health.status
    }

    Write-Host "Integration test passed." -ForegroundColor Green
    $summary | ConvertTo-Json -Compress | Write-Host
    exit 0
}
catch {
    Write-Host "Integration test failed." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
