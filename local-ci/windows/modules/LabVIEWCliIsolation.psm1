#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-RelativePathSafe {
    param(
        [string]$BasePath,
        [string]$TargetPath
    )
    if ([string]::IsNullOrWhiteSpace($BasePath) -or [string]::IsNullOrWhiteSpace($TargetPath)) {
        return $TargetPath
    }
    try {
        return [System.IO.Path]::GetRelativePath($BasePath, $TargetPath)
    } catch {
        return $TargetPath
    }
}

function ConvertTo-SafeLabel {
    param([string]$Label)
    if ([string]::IsNullOrWhiteSpace($Label)) { return 'labview-cli' }
    $safe = ($Label -replace '[^a-zA-Z0-9._-]','-')
    if ([string]::IsNullOrWhiteSpace($safe)) { return 'labview-cli' }
    return $safe.ToLowerInvariant()
}

function Enter-LabVIEWCliIsolation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RunRoot,
        [string]$Label = 'labview-cli'
    )

    if (-not (Test-Path -LiteralPath $RunRoot -PathType Container)) {
        New-Item -ItemType Directory -Path $RunRoot -Force | Out-Null
    }
    $resolvedRunRoot = (Resolve-Path -LiteralPath $RunRoot -ErrorAction Stop).Path
    $safeLabel = ConvertTo-SafeLabel -Label $Label
    $isolationRoot = Join-Path $resolvedRunRoot 'labview-cli'
    if (-not (Test-Path -LiteralPath $isolationRoot -PathType Container)) {
        New-Item -ItemType Directory -Path $isolationRoot -Force | Out-Null
    }
    $sessionName = "{0}-{1}" -f $safeLabel, (Get-Date -Format 'yyyyMMddHHmmssfff')
    $sessionRoot = Join-Path $isolationRoot $sessionName
    New-Item -ItemType Directory -Path $sessionRoot -Force | Out-Null

    $noticeDir = Join-Path $sessionRoot 'notice'
    $testsResults = Join-Path $sessionRoot 'tests' 'results'
    New-Item -ItemType Directory -Path $noticeDir -Force | Out-Null
    New-Item -ItemType Directory -Path $testsResults -Force | Out-Null

    $previous = @{
        LABVIEWCLI_RESULTS_ROOT = [Environment]::GetEnvironmentVariable('LABVIEWCLI_RESULTS_ROOT', 'Process')
        LV_NOTICE_DIR           = [Environment]::GetEnvironmentVariable('LV_NOTICE_DIR', 'Process')
    }

    [Environment]::SetEnvironmentVariable('LABVIEWCLI_RESULTS_ROOT', $sessionRoot, 'Process')
    [Environment]::SetEnvironmentVariable('LV_NOTICE_DIR', $noticeDir, 'Process')

    $startedAt = [DateTimeOffset]::UtcNow
    $sessionMetadataPath = Join-Path $sessionRoot 'session.json'
    $initialPayload = [ordered]@{
        schema = 'labview-cli/session@v1'
        label  = $safeLabel
        startedAt = $startedAt.ToString('o')
        paths = [ordered]@{
            sessionRoot = $sessionRoot
            resultsRoot = $testsResults
            noticeDir   = $noticeDir
        }
    }
    try {
        $initialPayload | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $sessionMetadataPath -Encoding utf8
    } catch {
        Write-Warning ("LabVIEW CLI isolation: failed to write session metadata at start: {0}" -f $_.Exception.Message)
        $sessionMetadataPath = $null
    }

    return [pscustomobject]@{
        SessionRoot          = $sessionRoot
        NoticeDir            = $noticeDir
        ResultsRoot          = $testsResults
        Previous             = $previous
        SessionMetadataPath  = $sessionMetadataPath
        Label                = $safeLabel
        StartedAt            = $startedAt
    }
}

function Exit-LabVIEWCliIsolation {
    [CmdletBinding()]
    param([psobject]$Isolation)

    if (-not $Isolation) { return }
    $previous = $Isolation.Previous
    $keys = @('LABVIEWCLI_RESULTS_ROOT','LV_NOTICE_DIR')
    foreach ($key in $keys) {
        $value = $null
        if ($previous -and $previous.ContainsKey($key)) { $value = $previous[$key] }
        [Environment]::SetEnvironmentVariable($key, $value, 'Process')
    }

    if ($Isolation -and $Isolation.SessionMetadataPath) {
        try {
            $stoppedAt = [DateTimeOffset]::UtcNow
            $startedAt = if ($Isolation.StartedAt) { [DateTimeOffset]$Isolation.StartedAt } else { $stoppedAt }
            $duration = ($stoppedAt - $startedAt).TotalSeconds
            $resultsDir = if ($Isolation.ResultsRoot) { $Isolation.ResultsRoot } else { $Isolation.SessionRoot }
            $artifacts = @{}

            $pidTrackerPath = Join-Path $resultsDir '_cli' '_agent' 'labview-pid.json'
            if (Test-Path -LiteralPath $pidTrackerPath -PathType Leaf) {
                $artifact = @{
                    path = Get-RelativePathSafe -BasePath $Isolation.SessionRoot -TargetPath $pidTrackerPath
                }
                try {
                    $trackerJson = Get-Content -LiteralPath $pidTrackerPath -Raw | ConvertFrom-Json -Depth 8 -ErrorAction Stop
                    if ($trackerJson -and $trackerJson.PSObject.Properties['pid']) {
                        $artifact['pid'] = $trackerJson.pid
                    }
                    if ($trackerJson -and $trackerJson.PSObject.Properties['running']) {
                        $artifact['running'] = $trackerJson.running
                    }
                } catch {}
                $artifacts['pidTracker'] = $artifact
            }

            $eventsPath = Join-Path $resultsDir '_cli' 'operation-events.ndjson'
            if (Test-Path -LiteralPath $eventsPath -PathType Leaf) {
                $artifacts['operationEvents'] = @{
                    path = Get-RelativePathSafe -BasePath $Isolation.SessionRoot -TargetPath $eventsPath
                }
            }

            $payload = [ordered]@{
                schema    = 'labview-cli/session@v1'
                label     = $Isolation.Label
                startedAt = $startedAt.ToString('o')
                stoppedAt = $stoppedAt.ToString('o')
                durationSeconds = [Math]::Round($duration,3)
                paths = [ordered]@{
                    sessionRoot = $Isolation.SessionRoot
                    resultsRoot = $resultsDir
                    noticeDir   = $Isolation.NoticeDir
                }
                artifacts = $artifacts
            }

            $payload | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $Isolation.SessionMetadataPath -Encoding utf8
        } catch {
            Write-Warning ("LabVIEW CLI isolation: failed to finalize session metadata: {0}" -f $_.Exception.Message)
        }
    }
}

Export-ModuleMember -Function Enter-LabVIEWCliIsolation, Exit-LabVIEWCliIsolation
