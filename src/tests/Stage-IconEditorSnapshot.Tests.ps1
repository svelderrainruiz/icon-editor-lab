
Describe 'Stage-IconEditorSnapshot.ps1' -Tag 'IconEditor','Snapshot','Unit' {
    BeforeAll {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
        Set-Variable -Scope Script -Name repoRoot -Value $repoRoot
        Set-Variable -Scope Script -Name stageScript -Value (Join-Path $repoRoot 'tools/icon-editor/Stage-IconEditorSnapshot.ps1')
        Set-Variable -Scope Script -Name vendorPath -Value (Join-Path $repoRoot 'vendor/labview-icon-editor')
        Set-Variable -Scope Script -Name fixturePath -Value $env:ICON_EDITOR_FIXTURE_PATH

        Test-Path -LiteralPath $script:stageScript | Should -BeTrue
        if (-not (Test-Path -LiteralPath $script:vendorPath -PathType Container)) {
            New-Item -ItemType Directory -Path $script:vendorPath -Force | Out-Null
        }
        $resourceDir = Join-Path $script:vendorPath 'resource'
        if (-not (Test-Path -LiteralPath $resourceDir -PathType Container)) {
            New-Item -ItemType Directory -Path $resourceDir -Force | Out-Null
        }
        Test-Path -LiteralPath $script:vendorPath | Should -BeTrue

        $script:snapshotStubRecords = @()
        function Script:Install-SnapshotScriptStub {
            param(
                [Parameter(Mandatory=$true)][string]$RelativePath,
                [Parameter(Mandatory=$true)][string]$Content
            )

            $target = Join-Path $script:repoRoot $RelativePath
            if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
                throw "Cannot stub missing snapshot helper: $RelativePath"
            }

            $backup = Join-Path $TestDrive ("snapshot-stub-{0}.ps1" -f ([guid]::NewGuid().ToString('n')))
            Copy-Item -LiteralPath $target -Destination $backup -Force
            Set-Content -LiteralPath $target -Value $Content -Encoding utf8

            $script:snapshotStubRecords += [pscustomobject]@{
                Target = $target
                Backup = $backup
            }
        }

        function Script:Restore-SnapshotScriptStubs {
            if (-not $script:snapshotStubRecords) { return }
            foreach ($entry in $script:snapshotStubRecords) {
                Copy-Item -LiteralPath $entry.Backup -Destination $entry.Target -Force
                Remove-Item -LiteralPath $entry.Backup -Force -ErrorAction SilentlyContinue
            }
            $script:snapshotStubRecords = @()
        }

        Install-SnapshotScriptStub -RelativePath 'tools/icon-editor/Describe-IconEditorFixture.ps1' -Content @'
param(
  [string]$FixturePath,
  [string]$ResultsRoot,
  [string]$OutputPath,
  [switch]$KeepWork,
  [switch]$SkipResourceOverlay,
  [string]$ResourceOverlayRoot
)
if (-not $ResultsRoot) {
  $ResultsRoot = Join-Path ([System.IO.Path]::GetTempPath()) 'describe-stub'
}
if (-not (Test-Path -LiteralPath $ResultsRoot -PathType Container)) {
  New-Item -ItemType Directory -Path $ResultsRoot -Force | Out-Null
}
$summary = [pscustomobject]@{
  schema    = 'icon-editor/fixture-report@v1'
  artifacts = @([pscustomobject]@{ name = 'vip'; path = $FixturePath })
}
if ($OutputPath) {
  $dir = Split-Path -Parent $OutputPath
  if ($dir -and -not (Test-Path -LiteralPath $dir -PathType Container)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
  }
  $summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutputPath -Encoding utf8
}
return $summary
'@

        Install-SnapshotScriptStub -RelativePath 'tools/icon-editor/Update-IconEditorFixtureReport.ps1' -Content @'
param(
  [string]$FixturePath,
  [string]$ManifestPath,
  [string]$ResultsRoot,
  [string]$ResourceOverlayRoot,
  [switch]$SkipDocUpdate,
  [switch]$CheckOnly,
  [switch]$NoSummary
)
if (-not $ResultsRoot) {
  $ResultsRoot = Join-Path ([System.IO.Path]::GetTempPath()) 'fixture-report-stub'
}
if (-not (Test-Path -LiteralPath $ResultsRoot -PathType Container)) {
  New-Item -ItemType Directory -Path $ResultsRoot -Force | Out-Null
}
$reportPath = Join-Path $ResultsRoot 'fixture-report.json'
$report = [pscustomobject]@{
  schema = 'icon-editor/fixture-report@v1'
  artifacts = @([pscustomobject]@{ name = 'vip'; path = $FixturePath })
}
$report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $reportPath -Encoding utf8
if ($ManifestPath) {
  $manifest = [pscustomobject]@{
    schema  = 'icon-editor/fixture-manifest@v1'
    entries = @([pscustomobject]@{ path = $FixturePath; checksum = 'stub' })
  }
  $manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $ManifestPath -Encoding utf8
}
return [pscustomobject]@{
  reportPath = $reportPath
}
'@
    }

    BeforeEach {
        Set-Variable -Name StageDevModeLog -Scope Global -Value (New-Object System.Collections.Generic.List[object])
        function Get-IconEditorDevModePolicyEntry {
            param(
                [string]$Operation,
                [string]$RepoRoot
            )
            return [pscustomobject]@{
                Operation = $Operation
                Versions  = @(2025)
                Bitness   = @(64)
                Path      = 'tests-policy.json'
            }
        }
        function Enable-IconEditorDevelopmentMode {
            param(
                [int[]]$Versions,
                [int[]]$Bitness,
                [string]$RepoRoot,
                [string]$IconEditorRoot,
                [string]$Operation
            )
            $Global:StageDevModeLog.Add([pscustomobject]@{
                Action   = 'enable'
                Versions = $Versions
                Bitness  = $Bitness
                Operation = $Operation
            }) | Out-Null
        }
        function Disable-IconEditorDevelopmentMode {
            param(
                [int[]]$Versions,
                [int[]]$Bitness,
                [string]$RepoRoot,
                [string]$IconEditorRoot,
                [string]$Operation
            )
            $Global:StageDevModeLog.Add([pscustomobject]@{
                Action   = 'disable'
                Versions = $Versions
                Bitness  = $Bitness
                Operation = $Operation
            }) | Out-Null
        }
        function Get-IconEditorDevModeLabVIEWTargets {
            param(
                [string]$RepoRoot,
                [string]$IconEditorRoot,
                [int[]]$Versions,
                [int[]]$Bitness
            )
            return @(
                [pscustomobject]@{
                    Version = 2025
                    Bitness = 64
                    Present = $true
                },
                [pscustomobject]@{
                    Version = 2021
                    Bitness = 64
                    Present = $true
                }
            )
        }
    }

    AfterEach {
        Remove-Item Function:Enable-IconEditorDevelopmentMode -ErrorAction SilentlyContinue
        Remove-Item Function:Disable-IconEditorDevelopmentMode -ErrorAction SilentlyContinue
        Remove-Item Function:Get-IconEditorDevModeLabVIEWTargets -ErrorAction SilentlyContinue
        Remove-Item Function:Get-IconEditorDevModePolicyEntry -ErrorAction SilentlyContinue
        Remove-Variable -Name StageDevModeLog -Scope Global -ErrorAction SilentlyContinue
    }

    It 'stages a snapshot using an existing source and skips validation' {
        if (-not $script:fixturePath -or -not (Test-Path -LiteralPath $script:fixturePath -PathType Leaf)) {
            Set-ItResult -Skip -Because 'ICON_EDITOR_FIXTURE_PATH not supplied; skipping snapshot staging test.'
            return
        }

        $workspaceRoot = Join-Path $TestDrive 'workspace'
        $result = & $script:stageScript `
            -SourcePath $script:vendorPath `
            -WorkspaceRoot $workspaceRoot `
            -StageName 'unit-snapshot' `
            -FixturePath $script:fixturePath `
            -SkipValidate

        $result | Should -Not -BeNullOrEmpty
        $result.stageRoot | Should -Match 'unit-snapshot$'
        Test-Path -LiteralPath $result.stageRoot -PathType Container | Should -BeTrue
        Test-Path -LiteralPath $result.resourceOverlay -PathType Container | Should -BeTrue
        Test-Path -LiteralPath $result.headManifestPath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $result.headReportPath -PathType Leaf | Should -BeTrue
        $result.validateRoot | Should -BeNullOrEmpty

        $manifest = Get-Content -LiteralPath $result.headManifestPath -Raw | ConvertFrom-Json -Depth 10
        $manifest.schema | Should -Be 'icon-editor/fixture-manifest@v1'
        ($manifest.entries | Measure-Object).Count | Should -BeGreaterThan 0

        $report = Get-Content -LiteralPath $result.headReportPath -Raw | ConvertFrom-Json -Depth 10
        $report.schema | Should -Be 'icon-editor/fixture-report@v1'
        $Global:StageDevModeLog.Count | Should -Be 0

        $result.sessionIndexPath | Should -Be (Join-Path $result.stageRoot 'session-index.json')
        Test-Path -LiteralPath $result.sessionIndexPath -PathType Leaf | Should -BeTrue
        $snapshotIndex = Get-Content -LiteralPath $result.sessionIndexPath -Raw | ConvertFrom-Json -Depth 6
        $snapshotIndex.schema | Should -Be 'icon-editor/snapshot-session@v1'
        $snapshotIndex.label | Should -Be 'unit-snapshot'
        $snapshotIndex.stage.root | Should -Be $result.stageRoot
        $snapshotIndex.validation.enabled | Should -BeFalse
        $snapshotIndex.fixture.headReportPath | Should -Be $result.headReportPath
    }

    It 'invokes the provided validate helper with dry-run semantics' {
        if (-not $script:fixturePath -or -not (Test-Path -LiteralPath $script:fixturePath -PathType Leaf)) {
            Set-ItResult -Skip -Because 'ICON_EDITOR_FIXTURE_PATH not supplied; skipping snapshot staging test.'
            return
        }

        $workspaceRoot = Join-Path $TestDrive 'workspace'
        $validateStubDir = Join-Path $TestDrive 'validate-stub'
        $null = New-Item -ItemType Directory -Path $validateStubDir -Force
        $logPath = Join-Path $validateStubDir 'log.json'
        $validateStub = Join-Path $validateStubDir 'Invoke-ValidateLocal.ps1'
$stubTemplate = @'
param(
  [string]$BaselineFixture,
  [string]$BaselineManifest,
  [string]$ResourceOverlayRoot,
  [string]$ResultsRoot,
  [switch]$SkipLVCompare,
  [switch]$DryRun,
  [switch]$SkipBootstrap
)
$payload = [ordered]@{
  baselineFixture  = $BaselineFixture
  baselineManifest = $BaselineManifest
  resourceOverlay  = $ResourceOverlayRoot
  resultsRoot      = $ResultsRoot
  skipLVCompare    = $SkipLVCompare.IsPresent
  dryRun           = $DryRun.IsPresent
  skipBootstrap    = $SkipBootstrap.IsPresent
}
$payload | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath "__LOG_PATH__" -Encoding utf8
'@
$stubTemplate.Replace('__LOG_PATH__', $logPath) | Set-Content -LiteralPath $validateStub -Encoding utf8

        $result = & $script:stageScript `
            -SourcePath $script:vendorPath `
            -WorkspaceRoot $workspaceRoot `
            -StageName 'unit-dryrun' `
            -FixturePath $script:fixturePath `
            -InvokeValidateScript $validateStub `
            -DryRun `
            -SkipBootstrapForValidate

        $result | Should -Not -BeNullOrEmpty
        Test-Path -LiteralPath $result.validateRoot -PathType Container | Should -BeTrue
        Test-Path -LiteralPath $logPath -PathType Leaf | Should -BeTrue

        $log = Get-Content -LiteralPath $logPath -Raw | ConvertFrom-Json -Depth 4
        $log.resultsRoot | Should -Be $result.validateRoot
        ($log.skipLVCompare -eq $true) | Should -BeTrue
        ($log.dryRun -eq $true) | Should -BeTrue
        ($log.skipBootstrap -eq $true) | Should -BeTrue
        Test-Path -LiteralPath $log.resourceOverlay -PathType Container | Should -BeTrue

        $Global:StageDevModeLog.Count | Should -Be 2
        $Global:StageDevModeLog[0].Action | Should -Be 'enable'
        $Global:StageDevModeLog[0].Operation | Should -Be 'Compare'
        ($Global:StageDevModeLog[0].Versions -join ',') | Should -Be '2025'
        ($Global:StageDevModeLog[0].Bitness -join ',')  | Should -Be '64'
        $Global:StageDevModeLog[1].Action | Should -Be 'disable'
        $Global:StageDevModeLog[1].Operation | Should -Be 'Compare'
        ($Global:StageDevModeLog[1].Versions -join ',') | Should -Be '2025'
        ($Global:StageDevModeLog[1].Bitness -join ',')  | Should -Be '64'

        Test-Path -LiteralPath $result.sessionIndexPath -PathType Leaf | Should -BeTrue
        $snapshotIndex = Get-Content -LiteralPath $result.sessionIndexPath -Raw | ConvertFrom-Json -Depth 6
        $snapshotIndex.validation.enabled | Should -BeTrue
        $snapshotIndex.validation.resultsRoot | Should -Be $result.validateRoot
        $snapshotIndex.devMode.enabled | Should -BeTrue
        $snapshotIndex.devMode.operation | Should -Be 'Compare'
    }

    It 'honours baseline environment variables when parameters are omitted' {
        if (-not $script:fixturePath -or -not (Test-Path -LiteralPath $script:fixturePath -PathType Leaf)) {
            Set-ItResult -Skip -Because 'ICON_EDITOR_FIXTURE_PATH not supplied; skipping snapshot staging test.'
            return
        }

        $baselineFixturePath = Join-Path $TestDrive 'baseline-fixture.vip'
        'stub baseline fixture' | Set-Content -LiteralPath $baselineFixturePath -Encoding utf8
        $baselineManifestPath = Join-Path $TestDrive 'baseline-manifest.json'
        '{}' | Set-Content -LiteralPath $baselineManifestPath -Encoding utf8

        $workspaceRoot = Join-Path $TestDrive 'workspace-env'
        $logDir = Join-Path $TestDrive 'validate-env'
        $null = New-Item -ItemType Directory -Path $logDir -Force
        $logPath = Join-Path $logDir 'log.json'
        $validateStub = Join-Path $logDir 'Invoke-ValidateLocal.ps1'
$stubTemplate = @'
param(
  [string]$BaselineFixture,
  [string]$BaselineManifest,
  [string]$ResourceOverlayRoot,
  [string]$ResultsRoot
)
$payload = [ordered]@{
  baselineFixture  = $BaselineFixture
  baselineManifest = $BaselineManifest
  resourceOverlay  = $ResourceOverlayRoot
  resultsRoot      = $ResultsRoot
}
$payload | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath "__LOG_PATH__" -Encoding utf8
'@
$stubTemplate.Replace('__LOG_PATH__', $logPath) | Set-Content -LiteralPath $validateStub -Encoding utf8

        $originalBaselineFixture = $env:ICON_EDITOR_BASELINE_FIXTURE_PATH
        $originalBaselineManifest = $env:ICON_EDITOR_BASELINE_MANIFEST_PATH
        try {
            $env:ICON_EDITOR_BASELINE_FIXTURE_PATH = $baselineFixturePath
            $env:ICON_EDITOR_BASELINE_MANIFEST_PATH = $baselineManifestPath

            $result = & $script:stageScript `
                -SourcePath $script:vendorPath `
                -WorkspaceRoot $workspaceRoot `
                -StageName 'env-baseline' `
                -FixturePath $script:fixturePath `
                -InvokeValidateScript $validateStub `
                -SkipDevMode

            $result | Should -Not -BeNullOrEmpty
            Test-Path -LiteralPath $logPath -PathType Leaf | Should -BeTrue

            $log = Get-Content -LiteralPath $logPath -Raw | ConvertFrom-Json -Depth 3
            $log.baselineFixture | Should -Be (Resolve-Path -LiteralPath $baselineFixturePath).Path
            $log.baselineManifest | Should -Be (Resolve-Path -LiteralPath $baselineManifestPath).Path
            Test-Path -LiteralPath $log.resultsRoot -PathType Container | Should -BeTrue

            $snapshotIndex = Get-Content -LiteralPath $result.sessionIndexPath -Raw | ConvertFrom-Json -Depth 6
            $snapshotIndex.fixture.baselineFixturePath | Should -Be (Resolve-Path -LiteralPath $baselineFixturePath).Path
            $snapshotIndex.fixture.baselineManifestPath | Should -Be (Resolve-Path -LiteralPath $baselineManifestPath).Path
        }
        finally {
            if ($null -ne $originalBaselineFixture) {
                $env:ICON_EDITOR_BASELINE_FIXTURE_PATH = $originalBaselineFixture
            } else {
                Remove-Item Env:ICON_EDITOR_BASELINE_FIXTURE_PATH -ErrorAction SilentlyContinue
            }
            if ($null -ne $originalBaselineManifest) {
                $env:ICON_EDITOR_BASELINE_MANIFEST_PATH = $originalBaselineManifest
            } else {
                Remove-Item Env:ICON_EDITOR_BASELINE_MANIFEST_PATH -ErrorAction SilentlyContinue
            }
        }
    }

    It 'honors dev mode overrides' {
        $workspaceRoot = Join-Path $TestDrive 'workspace'
        $validateStubDir = Join-Path $TestDrive 'validate-override'
        $null = New-Item -ItemType Directory -Path $validateStubDir -Force
        $logPath = Join-Path $validateStubDir 'log.json'
        $validateStub = Join-Path $validateStubDir 'Invoke-ValidateLocal.ps1'
$stubTemplate = @'
param(
  [string]$BaselineFixture,
  [string]$BaselineManifest,
  [string]$ResourceOverlayRoot,
  [string]$ResultsRoot,
  [switch]$SkipLVCompare,
  [switch]$DryRun,
  [switch]$SkipBootstrap
)
$payload = [ordered]@{
  baselineFixture  = $BaselineFixture
  baselineManifest = $BaselineManifest
  resourceOverlay  = $ResourceOverlayRoot
  resultsRoot      = $ResultsRoot
  skipLVCompare    = $SkipLVCompare.IsPresent
  dryRun           = $DryRun.IsPresent
  skipBootstrap    = $SkipBootstrap.IsPresent
}
$payload | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath "__LOG_PATH__" -Encoding utf8
'@
$stubTemplate.Replace('__LOG_PATH__', $logPath) | Set-Content -LiteralPath $validateStub -Encoding utf8

        if (-not $script:fixturePath -or -not (Test-Path -LiteralPath $script:fixturePath -PathType Leaf)) {
            Set-ItResult -Skip -Because 'ICON_EDITOR_FIXTURE_PATH not supplied; skipping snapshot staging test.'
            return
        }

        $result = & $script:stageScript `
            -SourcePath $script:vendorPath `
            -WorkspaceRoot $workspaceRoot `
            -StageName 'unit-override' `
            -FixturePath $script:fixturePath `
            -InvokeValidateScript $validateStub `
            -DryRun `
            -SkipBootstrapForValidate `
            -DevModeVersions @(2025) `
            -DevModeBitness @(32)

        $result | Should -Not -BeNullOrEmpty
        Test-Path -LiteralPath $result.validateRoot -PathType Container | Should -BeTrue
        Test-Path -LiteralPath $logPath -PathType Leaf | Should -BeTrue

        $Global:StageDevModeLog.Count | Should -Be 2
        $Global:StageDevModeLog[0].Action | Should -Be 'enable'
        $Global:StageDevModeLog[0].Operation | Should -Be 'Compare'
        ($Global:StageDevModeLog[0].Versions -join ',') | Should -Be '2025'
        ($Global:StageDevModeLog[0].Bitness -join ',')  | Should -Be '32'
        $Global:StageDevModeLog[1].Action | Should -Be 'disable'
        $Global:StageDevModeLog[1].Operation | Should -Be 'Compare'
        ($Global:StageDevModeLog[1].Versions -join ',') | Should -Be '2025'
        ($Global:StageDevModeLog[1].Bitness -join ',')  | Should -Be '32'
    }

    It 'propagates SkipLVCompare flag to Invoke-ValidateLocal' {
        if (-not $script:fixturePath -or -not (Test-Path -LiteralPath $script:fixturePath -PathType Leaf)) {
            Set-ItResult -Skip -Because 'ICON_EDITOR_FIXTURE_PATH not supplied; skipping snapshot staging test.'
            return
        }

        $workspaceRoot = Join-Path $TestDrive 'workspace-skipcompare'
        $validateStubDir = Join-Path $TestDrive 'validate-skipcompare'
        $null = New-Item -ItemType Directory -Path $validateStubDir -Force
        $logPath = Join-Path $validateStubDir 'log.json'
        $validateStub = Join-Path $validateStubDir 'Invoke-ValidateLocal.ps1'
$stubTemplate = @'
param(
  [string]$BaselineFixture,
  [string]$BaselineManifest,
  [string]$ResourceOverlayRoot,
  [string]$ResultsRoot,
  [switch]$SkipLVCompare,
  [switch]$DryRun,
  [switch]$SkipBootstrap
)
$payload = [ordered]@{
  skipLVCompare = $SkipLVCompare.IsPresent
  dryRun        = $DryRun.IsPresent
  skipBootstrap = $SkipBootstrap.IsPresent
}
$payload | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath "__LOG_PATH__" -Encoding utf8
'@
$stubTemplate.Replace('__LOG_PATH__', $logPath) | Set-Content -LiteralPath $validateStub -Encoding utf8

        $result = & $script:stageScript `
            -SourcePath $script:vendorPath `
            -WorkspaceRoot $workspaceRoot `
            -StageName 'unit-skip-compare' `
            -FixturePath $script:fixturePath `
            -InvokeValidateScript $validateStub `
            -SkipLVCompare `
            -SkipDevMode

        $result | Should -Not -BeNullOrEmpty
        Test-Path -LiteralPath $result.validateRoot -PathType Container | Should -BeTrue
        Test-Path -LiteralPath $logPath -PathType Leaf | Should -BeTrue

        $log = Get-Content -LiteralPath $logPath -Raw | ConvertFrom-Json -Depth 3
        $log.skipLVCompare | Should -BeTrue
        $log.dryRun | Should -BeFalse
        $log.skipBootstrap | Should -BeFalse

        $snapshotIndex = Get-Content -LiteralPath $result.sessionIndexPath -Raw | ConvertFrom-Json -Depth 6
        $snapshotIndex.validation.enabled | Should -BeTrue
        ($snapshotIndex.validation.resultsRoot -ne $null) | Should -BeTrue
    }

    It 'fails when LabVIEW 2025 x64 is unavailable' {
        function Get-IconEditorDevModeLabVIEWTargets {
            param(
                [string]$RepoRoot,
                [string]$IconEditorRoot,
                [int[]]$Versions,
                [int[]]$Bitness
            )
            return @(
                [pscustomobject]@{
                    Version = 2021
                    Bitness = 64
                    Present = $true
                }
            )
        }

        if (-not $script:fixturePath -or -not (Test-Path -LiteralPath $script:fixturePath -PathType Leaf)) {
            Set-ItResult -Skip -Because 'ICON_EDITOR_FIXTURE_PATH not supplied; skipping snapshot staging test.'
            return
        }

        $workspaceRoot = Join-Path $TestDrive 'workspace-missing'
        $validateStubDir = Join-Path $TestDrive 'validate-missing'
        $null = New-Item -ItemType Directory -Path $validateStubDir -Force
        $validateStub = Join-Path $validateStubDir 'Invoke-ValidateLocal.ps1'
        $logPath = Join-Path $validateStubDir 'log.txt'
$stubTemplate = @'
param()
"validate-called" | Set-Content -LiteralPath "__LOG_PATH__" -Encoding utf8
'@
$stubTemplate.Replace('__LOG_PATH__', $logPath) | Set-Content -LiteralPath $validateStub -Encoding utf8

        $threw = $false
        try {
            & $script:stageScript `
                -SourcePath $script:vendorPath `
                -WorkspaceRoot $workspaceRoot `
                -StageName 'missing-dev-mode' `
                -FixturePath $script:fixturePath `
                -InvokeValidateScript $validateStub `
                -DryRun `
                -SkipBootstrapForValidate
        } catch {
            $threw = $true
            $_.Exception.Message | Should -Match 'LabVIEW 2025 64-bit not detected'
        }
        $threw | Should -BeTrue

        $Global:StageDevModeLog.Count | Should -Be 0
    }

    AfterAll {
        Restore-SnapshotScriptStubs
    }
}


