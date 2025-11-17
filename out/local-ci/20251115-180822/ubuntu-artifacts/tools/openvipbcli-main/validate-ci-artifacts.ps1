# validate-ci-artifacts.ps1
# Safely fetch and validate CI artifacts (Pester & Jest) via GitHub CLI

[CmdletBinding()]
param (
    [string]$Workflow         = 'ci.yml',
    [string]$Branch           = 'main',
    [string]$PesterArtifact   = 'pester-artifacts',
    [string]$JestArtifact     = 'jest-artifacts',
    [string]$PesterPattern    = 'Tests Passed:.*Failed: 0',
    [string]$JestSuitePattern = 'Test Suites:.*0 failed',
    [string]$JestTestPattern  = 'Tests:.*0 failed',
    [int]   $MinCoverage
)

# Load coverage threshold from config if not explicitly passed
if (-not $PSBoundParameters.ContainsKey('MinCoverage')) {
    if (-not (Test-Path '.ci/coverage-policy.json')) {
        Fail "Coverage policy not found at '.ci/coverage-policy.json'"
    }
    try {
        $policy = Get-Content '.ci/coverage-policy.json' -Raw | ConvertFrom-Json
    } catch {
        Fail "Failed to parse coverage policy JSON: $_"
    }
    if (-not $policy.minLineCoveragePercent) {
        Fail "Coverage policy is missing 'minLineCoveragePercent'"
    }
    $MinCoverage = [int]$policy.minLineCoveragePercent
}

function Fail {
    param([string]$Message)
    Write-Error $Message
    exit 1
}

# 1) Ensure gh CLI is available
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Fail "GitHub CLI ('gh') not found. Install it from https://cli.github.com/ and authenticate."
}

# 2) Ensure we're authenticated
$auth = gh auth status 2>&1
if ($LASTEXITCODE -ne 0 -or $auth -match 'not logged in') {
    Fail "GitHub CLI not authenticated. Run 'gh auth login --with-token' or 'gh auth login'."
}

# 3) Fetch the latest workflow run ID
$run = gh run list `
    --workflow $Workflow `
    --branch $Branch `
    --limit 1 `
    --json id `
    --jq '.[0].id' 2>&1

if ($LASTEXITCODE -ne 0 -or -not $run) {
    Fail "Failed to retrieve the latest run ID for workflow '$Workflow' on branch '$Branch': $run"
}
$run = $run.Trim()
Write-Host "Latest run ID: $run"

# 4) Download artifacts
Write-Host "Downloading Pester artifacts..."
gh run download $run --name $PesterArtifact --dir .\ci-artifacts\pester 2>&1
if ($LASTEXITCODE -ne 0) { Fail "Failed to download Pester artifacts '$PesterArtifact'." }

Write-Host "Downloading Jest artifacts..."
gh run download $run --name $JestArtifact --dir .\ci-artifacts\jest 2>&1
if ($LASTEXITCODE -ne 0) { Fail "Failed to download Jest artifacts '$JestArtifact'." }

# 5) Validate Pester results
$pesterLog = ".\ci-artifacts\pester\pester.log"
if (-not (Test-Path $pesterLog)) {
    Fail "Pester log not found at '$pesterLog'"
}
if (-not (Select-String -Path $pesterLog -Pattern $PesterPattern -Quiet)) {
    Fail "Pester did not report zero failures. Pattern '$PesterPattern' not found in '$pesterLog'."
}
Write-Host "✅ Pester tests passed"

# 6) Validate Jest results
$jestLog = ".\ci-artifacts\jest\jest-output.log"
if (-not (Test-Path $jestLog)) {
    Fail "Jest log not found at '$jestLog'"
}
if (-not (Select-String -Path $jestLog -Pattern $JestSuitePattern -Quiet)) {
    Fail "Jest suite failures detected. Pattern '$JestSuitePattern' not found in '$jestLog'."
}
if (-not (Select-String -Path $jestLog -Pattern $JestTestPattern -Quiet)) {
    Fail "Jest test failures detected. Pattern '$JestTestPattern' not found in '$jestLog'."
}
Write-Host "✅ Jest tests passed"

# 7) Validate coverage ≥ threshold
$covPath = ".\ci-artifacts\jest\coverage\coverage-summary.json"
if (-not (Test-Path $covPath)) {
    Fail "Coverage summary not found at '$covPath'"
}
try {
    $covJson   = Get-Content $covPath | ConvertFrom-Json
    $pct       = [math]::Round($covJson.total.lines.pct, 2)
} catch {
    Fail "Failed to parse coverage JSON: $_"
}
Write-Host "Coverage: $pct`% (minimum required: $MinCoverage`%)"
if ($pct -lt $MinCoverage) {
    Fail "Coverage $pct`% is below the required threshold of $MinCoverage`%."
}
Write-Host "✅ Coverage threshold met"

Write-Host "`n🎉 All CI artifact validations passed!"
