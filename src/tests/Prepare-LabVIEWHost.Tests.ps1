
Describe 'Prepare-LabVIEWHost helper' -Tag 'Unit','IconEditor' {
  BeforeAll {
    $script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:prepScript = Join-Path $script:repoRoot 'tools/icon-editor/Prepare-LabVIEWHost.ps1'
  }

  It 'parses comma/space separated lists and returns a dry-run summary' {
    $fixturePath = Join-Path $TestDrive 'icon-editor.fixture.vip'
    Set-Content -LiteralPath $fixturePath -Value 'stub' -Encoding ascii
    $workspaceRoot = Join-Path $TestDrive 'snapshots'

    $reportsRoot = Join-Path $TestDrive 'reports-dry'
    New-Item -ItemType Directory -Path $reportsRoot -Force | Out-Null
    $envBackup = $env:COMPAREVI_REPORTS_ROOT
    $env:COMPAREVI_REPORTS_ROOT = $reportsRoot

    try {
      $result = & $script:prepScript `
      -FixturePath $fixturePath `
      -Versions '2099' `
      -Bitness '64' `
      -StageName 'unit-host-prep' `
      -WorkspaceRoot $workspaceRoot `
      -IconEditorRoot (Join-Path $script:repoRoot 'vendor/labview-icon-editor') `
      -SkipStage `
      -SkipDevMode `
      -SkipClose `
      -SkipReset `
      -SkipRogueDetection `
      -SkipPostRogueDetection `
      -DryRun
    } finally {
      $env:COMPAREVI_REPORTS_ROOT = $envBackup
    }

    $result | Should -Not -BeNullOrEmpty
    $result.stage | Should -Be 'unit-host-prep'
    $result.dryRun | Should -BeTrue
    $result.versions | Should -Be @(2099)
    $result.bitness | Should -Be @(64)
    Test-Path -LiteralPath $workspaceRoot | Should -BeTrue
    $result.telemetryPath | Should -Not -BeNullOrEmpty
    Test-Path -LiteralPath $result.telemetryPath | Should -BeTrue
    $result.devModeTelemetry | Should -BeNullOrEmpty

    $telemetry = Get-Content -LiteralPath $result.telemetryPath -Raw | ConvertFrom-Json -Depth 6
    $telemetry.schema | Should -Be 'icon-editor/host-prep@v1'
    $telemetry.steps.stage.skipped | Should -BeTrue
    $telemetry.steps.devMode.skipped | Should -BeTrue
    $telemetry.steps.close.skipped | Should -BeTrue
    $telemetry.steps.reset.skipped | Should -BeTrue
    @($telemetry.closures).Count | Should -Be 0
    $telemetry.PSObject.Properties['devModeTelemetry'] | Should -BeNullOrEmpty
  }

  It 'records dev-mode telemetry links when enable scripts run' {
    $testRepo = Join-Path $TestDrive ([guid]::NewGuid().ToString('n'))
    $toolsDir = Join-Path $testRepo 'tools'
    $iconEditorDir = Join-Path $testRepo 'vendor/labview-icon-editor'
    $actionsDir = Join-Path $iconEditorDir '.github/actions/close-labview'
    $resultsDir = Join-Path $testRepo 'tests/results'

    New-Item -ItemType Directory -Path `
      (Join-Path $toolsDir 'icon-editor'), `
      (Join-Path $toolsDir 'report'), `
      $iconEditorDir, `
      $actionsDir, `
      $resultsDir `
      -Force | Out-Null

    $stubScripts = @(
      @{ Path = Join-Path $toolsDir 'icon-editor/Stage-IconEditorSnapshot.ps1'; Content = "[CmdletBinding()]param()`nWrite-Host 'stage stub'" },
      @{ Path = Join-Path $toolsDir 'icon-editor/Reset-IconEditorWorkspace.ps1'; Content = "[CmdletBinding()]param()`nWrite-Host 'reset stub'" },
      @{ Path = Join-Path $toolsDir 'icon-editor/IconEditorDevMode.psm1'; Content = @"
function Test-IconEditorDevelopmentMode {
  param([string]`$RepoRoot,[string]`$IconEditorRoot,[int[]]`$Versions,[int[]]`$Bitness)
  return [pscustomobject]@{ Entries = @() }
}
Export-ModuleMember -Function Test-IconEditorDevelopmentMode
"@ },
      @{ Path = Join-Path $toolsDir 'Detect-RogueLV.ps1'; Content = "[CmdletBinding()]param()`nWrite-Host 'rogue stub'" },
      @{ Path = Join-Path $actionsDir 'Close_LabVIEW.ps1'; Content = "[CmdletBinding()]param()`nWrite-Host 'close stub'" },
      @{ Path = Join-Path $toolsDir 'Close-LabVIEW.ps1'; Content = "[CmdletBinding()]param()`nWrite-Host 'global close stub'" },
      @{ Path = Join-Path $toolsDir 'report/Write-RunReport.ps1'; Content = @"
[CmdletBinding()]
param(
  [string]`$Kind,
  [string]`$Label,
  [string]`$Command,
  [string]`$Summary,
  [string]`$Warnings,
  [string]`$TranscriptPath,
  [string]`$TelemetryPath,
  [hashtable]`$TelemetryLinks,
  [switch]`$Aborted,
  [string]`$AbortReason,
  [hashtable]`$Extra
)
`$reportPath = Join-Path (Split-Path -Parent `$PSCommandPath) ("stub-{0}.json" -f [guid]::NewGuid().ToString('n'))
@{ kind = `$Kind; telemetryLinks = `$TelemetryLinks } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath `$reportPath -Encoding utf8
Write-Host ("Report written to: {0}" -f `$reportPath)
return `$reportPath
"@ }
    )

    foreach ($stub in $stubScripts) {
      $dir = Split-Path -Parent $stub.Path
      if (-not (Test-Path -LiteralPath $dir -PathType Container)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
      }
      Set-Content -LiteralPath $stub.Path -Value $stub.Content -Encoding utf8
    }

    $enableStub = @"
[CmdletBinding()]
param(
  [string]`$RepoRoot,
  [string]`$IconEditorRoot,
  [int[]]`$Versions,
  [int[]]`$Bitness,
  [string]`$Operation
)
`$resultsRoot = Join-Path `$RepoRoot 'tests/results'
`$runRoot = Join-Path `$resultsRoot '_agent/icon-editor/dev-mode-run'
New-Item -ItemType Directory -Path `$runRoot -Force | Out-Null
`$label = "dev-mode-run-$([guid]::NewGuid().ToString('n'))"
`$payload = [ordered]@{
  schema = 'icon-editor/dev-mode-run@v1'
  label = `$label
  mode = 'enable'
  status = 'succeeded'
  startedAt = (Get-Date).ToString('o')
  completedAt = (Get-Date).ToString('o')
  settleSummary = @{
    totalEvents = 1
    succeededEvents = 1
    failedEvents = 0
    totalDurationSeconds = 0.1
  }
}
`$payload | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path `$runRoot ("$`label.json")) -Encoding utf8
"@
    Set-Content -LiteralPath (Join-Path $toolsDir 'icon-editor/Enable-DevMode.ps1') -Value $enableStub -Encoding utf8
    Set-Content -LiteralPath (Join-Path $toolsDir 'icon-editor/Disable-DevMode.ps1') -Value "[CmdletBinding()]param()" -Encoding utf8

    $fixturePath = Join-Path $testRepo 'icon-editor.fixture.vip'
    Set-Content -LiteralPath $fixturePath -Value 'stub' -Encoding ascii
    $workspaceRoot = Join-Path $testRepo 'snapshots'
    New-Item -ItemType Directory -Path $workspaceRoot -Force | Out-Null

    $reportsRoot = Join-Path $testRepo 'reports'
    New-Item -ItemType Directory -Path $reportsRoot -Force | Out-Null

    $envBackup = $env:COMPAREVI_REPORTS_ROOT
    $env:COMPAREVI_REPORTS_ROOT = $reportsRoot

    Push-Location $testRepo
    try {
      $result = & $script:prepScript `
        -FixturePath $fixturePath `
        -Versions 2099 `
        -Bitness 64 `
        -StageName 'unit-host-prep' `
        -WorkspaceRoot $workspaceRoot `
        -IconEditorRoot $iconEditorDir `
        -SkipStage `
        -SkipClose `
        -SkipReset `
        -SkipRogueDetection `
        -SkipPostRogueDetection
    } finally {
      $env:COMPAREVI_REPORTS_ROOT = $envBackup
      Pop-Location
    }

    $result.devModeTelemetry | Should -Not -BeNullOrEmpty
    $result.devModeTelemetry.enable | Should -Not -BeNullOrEmpty
    Test-Path -LiteralPath $result.devModeTelemetry.enable | Should -BeTrue
    $enableTelemetry = Get-Content -LiteralPath $result.devModeTelemetry.enable -Raw | ConvertFrom-Json
    $enableTelemetry.mode | Should -Be 'enable'
  }
}


