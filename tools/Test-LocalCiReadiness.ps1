#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$RepoRoot,
    [switch]$SkipWorkspacePolicy,
    [switch]$SkipTests,
    [switch]$SkipCoverage,
    [switch]$SkipHandshake,
    [switch]$SkipRunnerCheck,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-WorkspaceRoot {
    param([string]$Override)
    if ($Override) {
        return (Resolve-Path -LiteralPath $Override -ErrorAction Stop).ProviderPath
    }
    $root = $env:WORKSPACE_ROOT
    if (-not $root) { $root = '/mnt/data/repo_local' }
    if (-not (Test-Path -LiteralPath $root)) {
        $root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..') -ErrorAction Stop).ProviderPath
    } else {
        $root = (Resolve-Path -LiteralPath $root -ErrorAction Stop).ProviderPath
    }
    return $root
}

function Initialize-Directory {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
    }
}

$repoRoot = Get-WorkspaceRoot -Override $RepoRoot
Push-Location $repoRoot
try {
    $results = New-Object System.Collections.Generic.List[pscustomobject]
    $summaryLines = New-Object System.Collections.Generic.List[string]
    $artifactsRoot = Join-Path $repoRoot 'artifacts'
    Initialize-Directory -Path $artifactsRoot
    Initialize-Directory -Path (Join-Path $repoRoot '.tmp-tests')

    function Add-ReadinessResult {
        param(
            [string]$Name,
            [ValidateSet('PASS','FAIL','SKIP')]
            [string]$Status,
            [string]$Details,
            [string]$Remediation = '',
            [string]$Severity = 'Required'
        )
        $results.Add([pscustomobject]@{
            Name        = $Name
            Status      = $Status
            Details     = $Details
            Remediation = $Remediation
            Severity    = $Severity
        }) | Out-Null
    }

    # Workspace policy
    if ($SkipWorkspacePolicy) {
        Add-ReadinessResult -Name 'Workspace Policy' -Status 'SKIP' -Details 'Skipped via parameter.'
    } else {
        $gitStatus = git status --porcelain
        if ($LASTEXITCODE -ne 0) {
            Add-ReadinessResult -Name 'Workspace Policy' -Status 'FAIL' `
                -Details 'git status failed.' -Remediation 'Ensure git is installed and repository is initialized.'
        } elseif ($gitStatus) {
            Add-ReadinessResult -Name 'Workspace Policy' -Status 'FAIL' `
                -Details 'Working tree has uncommitted changes.' `
                -Remediation 'Commit or stash local changes before running readiness.'
        } else {
            $helperPath = Join-Path $repoRoot 'tests/_helpers/Import-ScriptFunctions.ps1'
            if (-not (Test-Path -LiteralPath $helperPath)) {
                Add-ReadinessResult -Name 'Workspace Policy' -Status 'FAIL' `
                    -Details 'tests/_helpers/Import-ScriptFunctions.ps1 missing.' `
                    -Remediation 'Re-run install scripts or pull latest tests.'
            } else {
                Add-ReadinessResult -Name 'Workspace Policy' -Status 'PASS' `
                    -Details "Repo root: $repoRoot"
            }
        }
    }

    # Run tests with Pester
    if ($SkipTests) {
        Add-ReadinessResult -Name 'Pester Tests' -Status 'SKIP' -Details 'Skipped via parameter.'
    } else {
        $testsPath = Join-Path $repoRoot 'tests'
        $resultsDir = Join-Path $artifactsRoot 'test-results'
        Initialize-Directory -Path $resultsDir
        $testOutput = Join-Path $resultsDir 'results.xml'
        try {
            $pesterResult = Invoke-Pester -Path $testsPath -CI -OutputFormat NUnitXml -OutputFile $testOutput -PassThru
            $testsTotal = $pesterResult.Results.Count
            $testsFailed = ($pesterResult.FailedCount)
            if ($testsFailed -gt 0) {
                Add-ReadinessResult -Name 'Pester Tests' -Status 'FAIL' `
                    -Details "Invoke-Pester reported $testsFailed failures (see $testOutput)." `
                    -Remediation 'Fix failing tests before continuing.'
            } else {
                Add-ReadinessResult -Name 'Pester Tests' -Status 'PASS' `
                    -Details "Invoke-Pester succeeded ($testsTotal tests). Results at $testOutput."
            }
        } catch {
            Add-ReadinessResult -Name 'Pester Tests' -Status 'FAIL' `
                -Details $_.Exception.Message `
                -Remediation 'Invoke-Pester failed; inspect the error and address before running CI.'
        }
    }

    # Coverage gates
    if ($SkipCoverage) {
        Add-ReadinessResult -Name 'Coverage Gates' -Status 'SKIP' -Details 'Skipped via parameter.'
    } else {
        $coveragePath = Join-Path $artifactsRoot 'coverage/coverage.xml'
        if (-not (Test-Path -LiteralPath $coveragePath)) {
            Add-ReadinessResult -Name 'Coverage Gates' -Status 'FAIL' `
                -Details "Coverage file missing at $coveragePath." `
                -Remediation 'Run Invoke-Pester with code coverage enabled.'
        } else {
            try {
                [xml]$coverageXml = Get-Content -LiteralPath $coveragePath
                $globalRate = [double]$coverageXml.coverage.'line-rate'
                $criticalFiles = @('src/Core.psm1','tools/Build.ps1')
                $perFileResults = @()
                $classes = @()
                foreach ($pkg in $coverageXml.coverage.packages.package) {
                    if ($pkg.classes.class) { $classes += $pkg.classes.class }
                }
                $perFileFailures = @()
                foreach ($file in $criticalFiles) {
                    $normalized = $file.Replace('\','/')
                    $match = $classes | Where-Object {
                        $_.filename -and ($_.filename.Replace('\','/') -ieq $normalized)
                    }
                    if (-not $match) {
                        continue
                    }
                    $lineRate = [double]$match.'line-rate'
                    $perFileResults += "$file=$([math]::Round($lineRate*100,2))%"
                    if ($lineRate -lt 0.75) {
                        $perFileFailures += "$file ($([math]::Round($lineRate*100,2))%)"
                    }
                }
                if ($globalRate -lt 0.75 -or $perFileFailures) {
                    $detail = "Global ${([math]::Round($globalRate*100,2))}%."
                    if ($perFileResults) { $detail += " Files: $([string]::Join(', ', $perFileResults))." }
                    if ($perFileFailures) { $detail += " Failing: $([string]::Join(', ', $perFileFailures))." }
                    Add-ReadinessResult -Name 'Coverage Gates' -Status 'FAIL' `
                        -Details $detail `
                        -Remediation 'Increase unit test coverage for failing targets.'
                } else {
                    $detail = "Global ${([math]::Round($globalRate*100,2))}%. "
                    if ($perFileResults) { $detail += "Files: $([string]::Join(', ', $perFileResults))." }
                    Add-ReadinessResult -Name 'Coverage Gates' -Status 'PASS' -Details $detail.Trim()
                }
            } catch {
                Add-ReadinessResult -Name 'Coverage Gates' -Status 'FAIL' `
                    -Details $_.Exception.Message `
                    -Remediation 'Ensure coverage.xml is valid Cobertura XML.'
            }
        }
    }

    # Handshake assets
    if ($SkipHandshake) {
        Add-ReadinessResult -Name 'Handshake Assets' -Status 'SKIP' -Details 'Skipped via parameter.'
    } else {
        $pointerPath = Join-Path $repoRoot 'handshake/pointer.json'
        $ubuntuPointer = Join-Path $repoRoot 'out/local-ci-ubuntu/latest.json'
        if (-not (Test-Path -LiteralPath $pointerPath) -or -not (Test-Path -LiteralPath $ubuntuPointer)) {
            Add-ReadinessResult -Name 'Handshake Assets' -Status 'FAIL' `
                -Details 'Pointer json or Ubuntu pointer missing.' `
                -Remediation 'Run the Ubuntu local-ci handshake stages first.'
        } else {
            try {
                $pointer = Get-Content -LiteralPath $pointerPath -Raw | ConvertFrom-Json
                $stamp = $pointer.ubuntu.stamp
                if (-not $stamp) {
                    throw "Ubuntu stamp missing in pointer."
                }
                $manifestPath = Join-Path $repoRoot "out/local-ci-ubuntu/$stamp/ubuntu-run.json"
                if (-not (Test-Path -LiteralPath $manifestPath)) {
                    throw "Manifest missing at $manifestPath"
                }
                Add-ReadinessResult -Name 'Handshake Assets' -Status 'PASS' `
                    -Details "Pointer stamp $stamp verified."
            } catch {
                Add-ReadinessResult -Name 'Handshake Assets' -Status 'FAIL' `
                    -Details $_.Exception.Message `
                    -Remediation 'Regenerate handshake artifacts via Ubuntu stages.'
            }
        }
    }

    # Runner coverage (best effort)
    if ($SkipRunnerCheck) {
        Add-ReadinessResult -Name 'Runner Coverage' -Status 'SKIP' -Details 'Skipped via parameter.' -Severity 'Informational'
    } else {
        $scriptPath = Join-Path $repoRoot 'scripts/workflows/check_windows_runner_coverage.py'
        $pythonCmd = Get-Command python3 -ErrorAction SilentlyContinue
        if (-not $pythonCmd) {
            $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
        }
        if (-not $pythonCmd -or -not (Test-Path -LiteralPath $scriptPath) -or -not $env:GITHUB_TOKEN) {
            Add-ReadinessResult -Name 'Runner Coverage' -Status 'SKIP' `
                -Details 'Python or GitHub token not available; skipping runner inventory.' `
                -Severity 'Informational'
        } else {
            try {
                $env:WINDOWS_RUNNER_LABELS = $env:WINDOWS_RUNNER_LABELS ?? '["self-hosted","Windows","X64"]'
                & $pythonCmd.Source $scriptPath *> $null
                if ($LASTEXITCODE -eq 0) {
                    Add-ReadinessResult -Name 'Runner Coverage' -Status 'PASS' `
                        -Details 'Matching Windows runner(s) available.' -Severity 'Informational'
                } else {
                    Add-ReadinessResult -Name 'Runner Coverage' -Status 'FAIL' `
                        -Details 'Runner coverage script reported failure.' `
                        -Remediation 'Ensure a Windows runner with the required labels is online before CI.' -Severity 'Informational'
                }
            } catch {
                Add-ReadinessResult -Name 'Runner Coverage' -Status 'FAIL' `
                    -Details $_.Exception.Message `
                    -Remediation 'Runner coverage check failed; inspect network/token configuration.' -Severity 'Informational'
            }
        }
    }

    $results | Format-Table Name,Status,Details | Out-String | Write-Host

    $reportPath = Join-Path $artifactsRoot 'local-ci-ready/report.json'
    Initialize-Directory -Path (Split-Path -Parent $reportPath)
    $results | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $reportPath -Encoding UTF8
    Write-Host "Readiness report written to $reportPath"

    $summaryPath = $env:GITHUB_STEP_SUMMARY
    if ($summaryPath) {
        $lines = New-Object System.Collections.Generic.List[string]
        $lines.Add('### Local CI Readiness') | Out-Null
        $lines.Add('') | Out-Null
        $lines.Add('| Check | Status | Details |') | Out-Null
        $lines.Add('|-------|--------|---------|') | Out-Null
        foreach ($r in $results) {
            $statusText = $r.Status
            $detailText = ($r.Details ?? '').Replace('|','\|')
            $lines.Add(('| {0} | {1} | {2} |' -f $r.Name, $statusText, $detailText)) | Out-Null
        }
        $lines.Add('') | Out-Null
        $lines.Add(('*Report:* `{0}`' -f $reportPath)) | Out-Null
        $lines.Add('') | Out-Null
        $lines.Add('*Required checks: Workspace Policy, Pester Tests, Coverage Gates, Handshake Assets.*') | Out-Null
        $lines.Add('') | Out-Null
        $linesText = [string]::Join([Environment]::NewLine, $lines)
        $linesText | Out-File -FilePath $summaryPath -Encoding utf8 -Append
    }

    $failures = $results | Where-Object { $_.Severity -eq 'Required' -and $_.Status -eq 'FAIL' }
    if ($failures -and -not $Force) {
        $failedNames = $failures | ForEach-Object { $_.Name }
        $message = "Local CI readiness failed: $([string]::Join(', ', $failedNames))."
        if ($env:GITHUB_ACTIONS -eq 'true') {
            Write-Host "::error::$message"
        }
        throw $message
    } elseif ($failures) {
        Write-Warning "Readiness reported failures but Force was specified."
    } else {
        Write-Host "Local CI readiness checks passed." -ForegroundColor Green
    }
} finally {
    Pop-Location
}
