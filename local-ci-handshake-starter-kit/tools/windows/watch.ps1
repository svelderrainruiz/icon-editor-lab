param(
  [string]$RepoRoot = (Get-Location).Path,
  [int]$PollSec = 5
)

$UbuntuRoot = Join-Path $RepoRoot "out\local-ci-ubuntu"
$WinRoot    = Join-Path $RepoRoot "out\local-ci-windows"
New-Item -ItemType Directory -Force -Path $WinRoot | Out-Null

function Claim-Run($runDir) {
  $claim = Join-Path $runDir "windows.claimed"
  try {
    $fs = [System.IO.File]::Open($claim, 'CreateNew', 'Write', 'None'); $fs.Close(); return $true
  } catch { return $false }
}

function Process-Run($runId) {
  $uRun = Join-Path $UbuntuRoot $runId
  $manifest = Join-Path $uRun "ubuntu-run.json"
  $requests = Join-Path $uRun "vi-diff-requests.json"
  if (!(Test-Path $manifest) -or !(Test-Path $requests)) { return }

  $wRun = Join-Path $WinRoot $runId
  $raw  = Join-Path $wRun "raw"
  $logs = Join-Path $wRun "logs"
  New-Item -ItemType Directory -Force -Path $raw,$logs | Out-Null

  $req = Get-Content $requests -Raw | ConvertFrom-Json
  $pairs = $req.pairs | Sort-Object pair_id

  foreach ($p in $pairs) {
    $pairId = $p.pair_id
    $outPair = Join-Path $raw ("lvcompare\" + $pairId)
    $capPair = Join-Path $raw ("captures\" + $pairId)
    New-Item -ItemType Directory -Force -Path $outPair,$capPair | Out-Null

    # Resolve project-relative to absolute Windows paths
    $baseline = Join-Path $RepoRoot $p.baseline.path
    $candidate= Join-Path $RepoRoot $p.candidate.path

    # TODO: Replace with real LVCompare/TestStand calls
    "Comparing $pairId`n$baseline`n$candidate" | Out-File (Join-Path $outPair "lvcompare-$pairId.log")
    # Create placeholder files to demonstrate the pipeline
    New-Item -ItemType File -Path (Join-Path $outPair "report.html") -Value "<html><body>Stub $pairId</body></html>" | Out-Null
    New-Item -ItemType File -Path (Join-Path $outPair "report.json") -Value "{""pair_id"":""$pairId"",""result"":""different""}" | Out-Null
  }

  # Write session-index.json
  $index = [PSCustomObject]@{
    schema_version = "v1"
    run_id = $runId
    pairs = @($pairs | ForEach-Object {
      [PSCustomObject]@{
        pair_id = $_.pair_id
        baseline = $_.baseline.path
        candidate = $_.candidate.path
        lvcompare = [PSCustomObject]@{
          html_report = "lvcompare/$($_.pair_id)/report.html"
          json_report = "lvcompare/$($_.pair_id)/report.json"
          log = "lvcompare/$($_.pair_id)/lvcompare-$($_.pair_id).log"
          exit_code = 0
        }
      }
    })
  }
  $index | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $raw "session-index.json")

  # Publish summary into Ubuntu run folder
  $summary = @{
    schema_version = "v1"
    run_id = $runId
    created_utc = (Get-Date).ToUniversalTime().ToString("s") + "Z"
    host = @{
      machine = $env:COMPUTERNAME
      os = (Get-CimInstance Win32_OperatingSystem).Caption
      labview_version = "2023 SP1 64-bit"
      labviewcli = "C:\Program Files\National Instruments\Shared\LabVIEW CLI\LabVIEWCLI.exe"
      lvcompare_version = "2023 SP1"
    }
    compare_summary = @{
      total_pairs = $pairs.Count
      completed = $pairs.Count
      failed = 0
      skipped = 0
      duration_sec = 0
    }
    raw_artifacts = @{
      primary_dir = (Join-Path $WinRoot "$runId\raw")
    }
    session_index_file = (Join-Path $WinRoot "$runId\raw\session-index.json")
    status = "ok"
  } | ConvertTo-Json -Depth 8

  $winPublish = Join-Path $uRun "windows"
  New-Item -ItemType Directory -Force -Path $winPublish | Out-Null
  $summary | Set-Content (Join-Path $winPublish "vi-compare.publish.json")
  "Published summary for $runId" | Out-File -Append (Join-Path $wRun "logs\windows-watch.log")
}

while ($true) {
  Get-ChildItem $UbuntuRoot -Directory | ForEach-Object {
    $runDir = $_.FullName
    $ready = Join-Path $runDir "_READY"
    $publish = Join-Path $runDir "windows\vi-compare.publish.json"
    if (Test-Path $ready -and -not (Test-Path $publish)) {
      if (Claim-Run $runDir) {
        Process-Run $_.Name
      }
    }
  }
  Start-Sleep -Seconds $PollSec
}
