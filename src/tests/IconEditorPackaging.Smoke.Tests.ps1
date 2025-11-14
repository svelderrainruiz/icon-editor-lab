Describe 'Icon Editor packaging smoke guards' -Tag 'IconEditor','Packaging','Smoke' {
    BeforeAll {
        Add-Type -AssemblyName System.IO.Compression.FileSystem

        function Script:Install-PackagingScriptStub {
            param(
                [Parameter(Mandatory = $true)][string]$TargetPath,
                [Parameter(Mandatory = $true)][string]$Content
            )

            if (-not (Test-Path -LiteralPath $TargetPath -PathType Leaf)) {
                throw "Cannot install stub; target missing: $TargetPath"
            }

            $backupPath = Join-Path $TestDrive ("packaging-stub-{0}.ps1" -f ([guid]::NewGuid().ToString('n')))
            Copy-Item -LiteralPath $TargetPath -Destination $backupPath -Force
            Set-Content -LiteralPath $TargetPath -Value $Content -Encoding utf8

            if (-not $script:packagingScriptBackups) {
                $script:packagingScriptBackups = @()
            }
            $script:packagingScriptBackups += [pscustomobject]@{
                Target = $TargetPath
                Backup = $backupPath
            }
        }

        function Script:Restore-PackagingScriptStubs {
            if (-not $script:packagingScriptBackups) { return }
            foreach ($entry in $script:packagingScriptBackups) {
                Copy-Item -LiteralPath $entry.Backup -Destination $entry.Target -Force
                Remove-Item -LiteralPath $entry.Backup -Force -ErrorAction SilentlyContinue
            }
            $script:packagingScriptBackups = @()
        }

        function New-TestIconEditorVip {
            param(
                [string]$Path,
                [string]$Version = '1.0.0.0'
            )

            $root = Join-Path $TestDrive ("vip-root-{0}" -f ([guid]::NewGuid().ToString('n')))
            $systemRoot = Join-Path $TestDrive ("vip-system-{0}" -f ([guid]::NewGuid().ToString('n')))

            New-Item -ItemType Directory -Path $root -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $root 'Packages') -Force | Out-Null
            New-Item -ItemType Directory -Path $systemRoot -Force | Out-Null

            @"
[Package]
Name="ni_icon_editor"
Version="$Version"
[Description]
License="MIT"
"@ | Set-Content -LiteralPath (Join-Path $root 'spec') -Encoding utf8

            New-Item -ItemType Directory -Path (Join-Path $systemRoot 'File Group 0\National Instruments\LabVIEW Icon Editor\Tooling\deployment') -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $systemRoot 'File Group 0\National Instruments\LabVIEW Icon Editor\scripts') -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $systemRoot 'File Group 0\National Instruments\LabVIEW Icon Editor\Test') -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $systemRoot 'File Group 0\National Instruments\LabVIEW Icon Editor\resource') -Force | Out-Null

            @"
[Package]
Name="ni_icon_editor_system"
Version="$Version"
[Description]
License="MIT"
"@ | Set-Content -LiteralPath (Join-Path $systemRoot 'spec') -Encoding utf8

            $deploymentRoot = Join-Path $systemRoot 'File Group 0\National Instruments\LabVIEW Icon Editor\Tooling\deployment'
            foreach ($name in @(
                'VIP_Pre-Install Custom Action 2021.vi',
                'VIP_Post-Install Custom Action 2021.vi',
                'VIP_Pre-Uninstall Custom Action 2021.vi',
                'VIP_Post-Uninstall Custom Action 2021.vi'
            )) {
                Set-Content -LiteralPath (Join-Path $deploymentRoot $name) -Value ("stub {0}" -f $name) -Encoding utf8
            }
            Set-Content -LiteralPath (Join-Path $deploymentRoot 'runner_dependencies.vipc') -Value 'stub vipc' -Encoding utf8

            Set-Content -LiteralPath (Join-Path $systemRoot 'File Group 0\National Instruments\LabVIEW Icon Editor\scripts\StubScript.vi') -Value 'script' -Encoding utf8
            Set-Content -LiteralPath (Join-Path $systemRoot 'File Group 0\National Instruments\LabVIEW Icon Editor\Test\StubTest.vi') -Value 'test' -Encoding utf8
            Set-Content -LiteralPath (Join-Path $systemRoot 'File Group 0\National Instruments\LabVIEW Icon Editor\resource\StubResource.vi') -Value 'resource' -Encoding utf8

            $systemVip = Join-Path $root ('Packages\ni_icon_editor_system-{0}.vip' -f $Version)
            if (Test-Path -LiteralPath $systemVip) { Remove-Item -LiteralPath $systemVip -Force }
            [System.IO.Compression.ZipFile]::CreateFromDirectory($systemRoot, $systemVip)

            $manifestDir = Join-Path $root 'File Group 0\National Instruments\LabVIEW Icon Editor\Tooling\deployment'
            if (-not (Test-Path -LiteralPath $manifestDir)) {
                New-Item -ItemType Directory -Path $manifestDir -Force | Out-Null
            }

            if (Test-Path -LiteralPath $Path) { Remove-Item -LiteralPath $Path -Force }
            [System.IO.Compression.ZipFile]::CreateFromDirectory($root, $Path)

            Remove-Item -LiteralPath $root -Recurse -Force
            Remove-Item -LiteralPath $systemRoot -Recurse -Force
        }

        function New-TestBaselineManifest {
            param(
                [string]$Path
            )
            $manifest = [ordered]@{
                schema  = 'icon-editor/fixture-manifest@v1'
                entries = @(
                    [ordered]@{
                        key       = 'resource:resource\StubResource.vi'
                        category  = 'resource'
                        path      = 'resource\StubResource.vi'
                        sizeBytes = 8
                        hash      = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
                    },
                    [ordered]@{
                        key       = 'test:tests\StubTest.vi'
                        category  = 'test'
                        path      = 'tests\StubTest.vi'
                        sizeBytes = 4
                        hash      = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
                    }
                )
            }
            $manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $Path -Encoding utf8
        }

        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
        Set-Variable -Scope Script -Name repoRoot -Value $repoRoot
        Set-Variable -Scope Script -Name describeScript -Value (Join-Path $repoRoot 'tools/icon-editor/Describe-IconEditorFixture.ps1')
        Set-Variable -Scope Script -Name updateReportScript -Value (Join-Path $repoRoot 'tools/icon-editor/Update-IconEditorFixtureReport.ps1')
        Set-Variable -Scope Script -Name stageScript -Value (Join-Path $repoRoot 'tools/icon-editor/Stage-IconEditorSnapshot.ps1')
        Set-Variable -Scope Script -Name validateScript -Value (Join-Path $repoRoot 'tools/icon-editor/Invoke-ValidateLocal.ps1')
        Set-Variable -Scope Script -Name renderScript -Value (Join-Path $repoRoot 'tools/icon-editor/Render-IconEditorFixtureReport.ps1')
        Set-Variable -Scope Script -Name prepareScript -Value (Join-Path $repoRoot 'tools/icon-editor/Prepare-FixtureViDiffs.ps1')
        Set-Variable -Scope Script -Name simulateScript -Value (Join-Path $repoRoot 'tools/icon-editor/Simulate-IconEditorBuild.ps1')
        Set-Variable -Scope Script -Name enableDevModeScript -Value (Join-Path $repoRoot 'tools/icon-editor/Enable-DevMode.ps1')
        Set-Variable -Scope Script -Name disableDevModeScript -Value (Join-Path $repoRoot 'tools/icon-editor/Disable-DevMode.ps1')

        Test-Path -LiteralPath $script:describeScript | Should -BeTrue
        Test-Path -LiteralPath $script:updateReportScript | Should -BeTrue
        Test-Path -LiteralPath $script:stageScript | Should -BeTrue
        Test-Path -LiteralPath $script:validateScript | Should -BeTrue
        Test-Path -LiteralPath $script:renderScript | Should -BeTrue
        Test-Path -LiteralPath $script:prepareScript | Should -BeTrue
        Test-Path -LiteralPath $script:simulateScript | Should -BeTrue

        $describeStub = @'
param(
    [Parameter(Mandatory=$true)][string]$FixturePath,
    [string]$ResultsRoot,
    [string]$OutputPath,
    [switch]$KeepWork,
    [switch]$SkipResourceOverlay,
    [string]$ResourceOverlayRoot
)
$summary = [pscustomobject]@{
    schema = 'icon-editor/fixture-report@v1'
    artifacts = @([pscustomobject]@{ name = 'vip'; path = $FixturePath })
    fixtureOnlyAssets = @([pscustomobject]@{ name = 'asset'; path = 'resource/Stub.vi' })
}
if ($OutputPath) {
    $dir = Split-Path -Parent $OutputPath
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $summary | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $OutputPath -Encoding utf8
}
return $summary
'@

$updateStub = @'
param(
    [Parameter(Mandatory=$true)][string]$FixturePath,
    [string]$ManifestPath,
    [Parameter(Mandatory=$true)][string]$ResultsRoot,
    [switch]$NoSummary
)
if (-not (Test-Path -LiteralPath $ResultsRoot)) {
    New-Item -ItemType Directory -Path $ResultsRoot -Force | Out-Null
}
$reportPath = Join-Path $ResultsRoot 'fixture-report.json'
$report = [pscustomobject]@{
    schema = 'icon-editor/fixture-report@v1'
    artifacts = @([pscustomobject]@{ name = 'vip'; path = $FixturePath })
    fixtureOnlyAssets = @([pscustomobject]@{ name = 'asset'; path = 'resource/Stub.vi' })
}
$report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $reportPath -Encoding utf8
if ($ManifestPath) {
    $dir = Split-Path -Parent $ManifestPath
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $manifest = [pscustomobject]@{
        schema = 'icon-editor/fixture-manifest@v1'
        entries = @([pscustomobject]@{ key = 'resource:stub'; path = 'resource/Stub.vi' })
    }
    $manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $ManifestPath -Encoding utf8
}
return [pscustomobject]@{
    ReportPath = $reportPath
    ManifestPath = $ManifestPath
}
'@

$stageStub = @'
param(
    [string]$SourcePath,
    [string]$StageName,
    [string]$WorkspaceRoot,
    [string]$FixturePath,
    [string]$BaselineFixture,
    [string]$BaselineManifest,
    [switch]$DryRun,
    [switch]$SkipValidate,
    [switch]$SkipLVCompare
)
if (-not $FixturePath) { throw 'FixturePath is required.' }
$workspace = if ($WorkspaceRoot) { $WorkspaceRoot } else { Join-Path $env:TEMP 'stage-workspace' }
if (-not (Test-Path -LiteralPath $workspace)) {
    New-Item -ItemType Directory -Path $workspace -Force | Out-Null
}
[pscustomobject]@{
    stageExecuted   = $true
    fixturePath     = (Resolve-Path $FixturePath).Path
    baselineFixture = if ($BaselineFixture) { (Resolve-Path $BaselineFixture).Path } else { $null }
    baselineManifest= if ($BaselineManifest) { (Resolve-Path $BaselineManifest).Path } else { $null }
    workspace       = $workspace
}
'@

$validateStub = @'
param(
    [string]$FixturePath,
    [switch]$SkipBootstrap,
    [switch]$DryRun,
    [switch]$SkipLVCompare
)
if (-not $FixturePath) { throw 'FixturePath is required.' }
return [pscustomobject]@{ validated = $true }
'@

$prepareStub = @'
param(
    [string]$ReportPath,
    [string]$BaselineManifestPath,
    [string]$BaselineFixturePath,
    [string]$OutputDir,
    [string]$VipDiffRequestsPath
)
if (-not $OutputDir) { $OutputDir = Join-Path $env:TEMP 'vi-diff-output' }
if (-not (Test-Path -LiteralPath $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}
if (-not $VipDiffRequestsPath) {
    $VipDiffRequestsPath = Join-Path $OutputDir 'vi-diff-requests.json'
}
$requests = @(
    [pscustomobject]@{ source = 'fixture'; target = 'baseline'; status = 'pending' }
)
$requests | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $VipDiffRequestsPath -Encoding utf8
return [pscustomobject]@{
    RequestsPath = $VipDiffRequestsPath
    Count        = $requests.Count
}
'@

$renderStub = @'
param(
    [string]$ReportPath,
    [string]$FixturePath,
    [string]$OutputPath
)
if (-not $OutputPath) {
    $OutputPath = Join-Path $env:TEMP 'fixture-report.md'
}
$dir = Split-Path -Parent $OutputPath
if ($dir -and -not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}
$content = @(
    '# Fixture Report',
    'Fixture-only manifest delta',
    'Added: resource/Stub.vi'
)
Set-Content -LiteralPath $OutputPath -Value $content -Encoding utf8
return $OutputPath
'@

$simulateStub = @'
param(
    [string]$FixturePath,
    [string]$ResultsRoot,
    [string]$VipDiffOutputDir,
    [string]$VipDiffRequestsPath,
    [pscustomobject]$ExpectedVersion,
    [switch]$SkipResourceOverlay
)
if (-not $ResultsRoot) { $ResultsRoot = Join-Path $env:TEMP 'simulate-results' }
New-Item -ItemType Directory -Path $ResultsRoot -Force | Out-Null
if (-not $VipDiffOutputDir) { $VipDiffOutputDir = Join-Path $ResultsRoot 'vip-diff' }
New-Item -ItemType Directory -Path $VipDiffOutputDir -Force | Out-Null
if (-not $VipDiffRequestsPath) { $VipDiffRequestsPath = Join-Path $VipDiffOutputDir 'vi-diff-requests.json' }
$summaryPath = Join-Path $ResultsRoot 'package-smoke-summary.json'
Set-Content -LiteralPath $summaryPath -Value '{\"result\":\"ok\"}' -Encoding utf8
@([pscustomobject]@{ item = 'stub-request'; version = $ExpectedVersion }) |
    ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $VipDiffRequestsPath -Encoding utf8
return [pscustomobject]@{ summaryPath = $summaryPath }
'@

$invokeDiffsStub = @'
param(
    [Parameter(Mandatory=$true)][string]$RequestsPath,
    [Parameter(Mandatory=$true)][string]$CapturesRoot,
    [Parameter(Mandatory=$true)][string]$SummaryPath,
    [switch]$DryRun,
    [int]$TimeoutSeconds = 0
)
if (-not (Test-Path -LiteralPath $CapturesRoot -PathType Container)) {
    New-Item -ItemType Directory -Path $CapturesRoot -Force | Out-Null
}
$log = [pscustomobject]@{
    requestsPath = $RequestsPath
    capturesRoot = $CapturesRoot
    summaryPath  = $SummaryPath
    dryRun       = $DryRun.IsPresent
    timeout      = $TimeoutSeconds
}
if ($env:PACKAGING_DIFF_LOG) {
    $log | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $env:PACKAGING_DIFF_LOG -Encoding utf8
}
$summary = [pscustomobject]@{
    counts = [pscustomobject]@{
        total   = 1
        same    = 0
        different = 0
        skipped = 0
        dryRun  = [int]$DryRun.IsPresent
        errors  = 0
    }
    requests = @(
        [pscustomobject]@{
            relPath  = 'resource/Stub.vi'
            status   = if ($DryRun.IsPresent) { 'dry-run' } else { 'executed' }
            message  = 'stub comparison'
            artifacts= @([pscustomobject]@{ name = 'capture'; path = 'captures/stub.png' })
        }
    )
}
$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $SummaryPath -Encoding utf8
'@

$vipmStub = @'
param(
    [string]$RepoRoot,
    [string]$IconEditorRoot,
    [string]$RepoSlug,
    [int]$MinimumSupportedLVVersion = 2023,
    [int]$PackageMinimumSupportedLVVersion = 2026,
    [int]$PackageSupportedBitness = 64,
    [switch]$SkipSync,
    [switch]$SkipVipcApply,
    [switch]$SkipBuild,
    [switch]$SkipRogueCheck,
    [switch]$SkipClose,
    [int]$Major = 1,
    [int]$Minor = 4,
    [int]$Patch = 1,
    [int]$Build,
    [string]$ResultsRoot,
    [switch]$VerboseOutput
)

if (-not $RepoRoot) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
}
if (-not $IconEditorRoot) {
    $IconEditorRoot = Join-Path $RepoRoot 'vendor\icon-editor'
}
if (-not (Test-Path -LiteralPath $IconEditorRoot -PathType Container)) {
    New-Item -ItemType Directory -Path $IconEditorRoot -Force | Out-Null
}

$logPath = if ($env:VIPM_TEST_LOG) { $env:VIPM_TEST_LOG } else { Join-Path $env:TEMP 'vipm-test.log' }
$entries = @(
    'detect',
    'apply-32-2023-2023',
    'close-32-2023-2023',
    'detect',
    'apply-64-2023-2023',
    'close-64-2023-2023',
    'detect',
    'apply-64-2026-2026',
    'close-64-2026-2026',
    'detect'
)
Set-Content -LiteralPath $logPath -Value $entries -Encoding utf8

if (-not $SkipSync) {
    $wrapperDir = Join-Path $IconEditorRoot 'tools'
    if (-not (Test-Path -LiteralPath $wrapperDir -PathType Container)) {
        New-Item -ItemType Directory -Path $wrapperDir -Force | Out-Null
    }
    $gcliWrapper = Join-Path $wrapperDir 'GCli.psm1'
    $vipmWrapper = Join-Path $wrapperDir 'Vipm.psm1'
@"
# Stub GCli wrapper referencing GCli.psm1
Import-Module (Join-Path $RepoRoot 'tools\GCli.psm1') -ErrorAction SilentlyContinue
"@ | Set-Content -LiteralPath $gcliWrapper -Encoding utf8
@"
# Stub Vipm wrapper referencing Vipm.psm1
Import-Module (Join-Path $RepoRoot 'tools\Vipm.psm1') -ErrorAction SilentlyContinue
"@ | Set-Content -LiteralPath $vipmWrapper -Encoding utf8
}

if (-not $SkipBuild) {
    if (-not $ResultsRoot) {
        $ResultsRoot = Join-Path $RepoRoot 'tests\results\_agent\icon-editor\vipm-cli-build'
    }
    if (-not $Build) {
        $Build = [int](Get-Date -Format 'yyMMdd')
    }
    $recordPath = $env:ICON_EDITOR_BUILD_RECORD
    if ($recordPath) {
        $payload = [pscustomobject]@{
            IconEditorRoot = $IconEditorRoot
            ResultsRoot    = $ResultsRoot
            BuildToolchain = 'vipm'
            MinimumSupportedLVVersion        = $MinimumSupportedLVVersion
            PackageMinimumSupportedLVVersion = $PackageMinimumSupportedLVVersion
            PackageSupportedBitness          = $PackageSupportedBitness
            Major = $Major
            Minor = $Minor
            Patch = $Patch
            Build = $Build
        }
        $payload | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $recordPath -Encoding utf8
    }
}

return $logPath
'@

        Install-PackagingScriptStub -TargetPath $script:describeScript -Content $describeStub
        Install-PackagingScriptStub -TargetPath $script:updateReportScript -Content $updateStub
        Install-PackagingScriptStub -TargetPath $script:stageScript -Content $stageStub
        Install-PackagingScriptStub -TargetPath $script:validateScript -Content $validateStub
        Install-PackagingScriptStub -TargetPath $script:prepareScript -Content $prepareStub
        Install-PackagingScriptStub -TargetPath $script:renderScript -Content $renderStub
        Install-PackagingScriptStub -TargetPath $script:simulateScript -Content $simulateStub
        Install-PackagingScriptStub -TargetPath (Join-Path $script:repoRoot 'tools/icon-editor/Invoke-FixtureViDiffs.ps1') -Content $invokeDiffsStub
        Install-PackagingScriptStub -TargetPath (Join-Path $script:repoRoot 'tools/icon-editor/Invoke-VipmCliBuild.ps1') -Content $vipmStub

        $fixtureVipPath = Join-Path $TestDrive 'synthetic-icon-editor.vip'
        $baselineVipPath = Join-Path $TestDrive 'synthetic-icon-editor-baseline.vip'
        $baselineManifestPath = Join-Path $TestDrive 'synthetic-baseline-manifest.json'

        New-TestIconEditorVip -Path $fixtureVipPath -Version '1.5.0.0'
        New-TestIconEditorVip -Path $baselineVipPath -Version '1.4.0.0'
        New-TestBaselineManifest -Path $baselineManifestPath

        $script:fixtureVipPath = (Resolve-Path -LiteralPath $fixtureVipPath).ProviderPath
        $script:baselineVipPath = (Resolve-Path -LiteralPath $baselineVipPath).ProviderPath
        $script:baselineManifestPath = (Resolve-Path -LiteralPath $baselineManifestPath).ProviderPath

        $env:ICON_EDITOR_FIXTURE_PATH = $script:fixtureVipPath
        $env:ICON_EDITOR_BASELINE_FIXTURE_PATH = $script:baselineVipPath
        $env:ICON_EDITOR_BASELINE_MANIFEST_PATH = $script:baselineManifestPath
    }

    It 'Enable-DevMode.ps1 forwards parameters to IconEditorDevMode' {
        $modulePath = Join-Path $script:repoRoot 'tools/icon-editor/IconEditorDevMode.psm1'
        $backupPath = Join-Path $TestDrive 'IconEditorDevMode.enable.bak'
        Copy-Item -LiteralPath $modulePath -Destination $backupPath -Force
        $Global:DevModeCallLog = @()
        $repoRoot = Join-Path $TestDrive 'repo-enable'
        $iconRoot = Join-Path $repoRoot 'icon'
        New-Item -ItemType Directory -Path $repoRoot,$iconRoot -Force | Out-Null

        try {
@'
function Resolve-IconEditorRepoRoot {
    if ($env:ICON_EDITOR_FAKE_REPO_ROOT) {
        return (Resolve-Path -LiteralPath $env:ICON_EDITOR_FAKE_REPO_ROOT).Path
    }
    return (Join-Path $env:TEMP 'icon-editor-repo')
}

function Resolve-IconEditorRoot {
    param([string]$RepoRoot)
    if ($env:ICON_EDITOR_FAKE_ICON_ROOT) {
        return (Resolve-Path -LiteralPath $env:ICON_EDITOR_FAKE_ICON_ROOT).Path
    }
    if ($RepoRoot) {
        return (Join-Path $RepoRoot 'icon')
    }
    return $RepoRoot
}

function Initialize-IconEditorDevModeTelemetry {
    param(
        [string]$Mode,
        [string]$RepoRoot,
        [string]$IconEditorRoot,
        [int[]]$Versions,
        [int[]]$Bitness,
        [string]$Operation
    )
    $tmp = Join-Path $env:TEMP ("telemetry-{0}.json" -f ([guid]::NewGuid().ToString('n')))
    return [pscustomobject]@{
        TelemetryPath = $tmp
        TelemetryLatestPath = $tmp
        Telemetry = @{}
    }
}

function Invoke-IconEditorTelemetryStage {
    param(
        [Parameter(Mandatory=$true)][pscustomobject]$Context,
        [string]$Name,
        [int]$ExpectedSeconds,
        [scriptblock]$Action
    )
    $stage = [pscustomobject]@{
        name        = $Name
        stage       = $null
        statePath   = $null
        snapshotPath= $null
        settleEvents= @()
        exitCode    = $null
    }
    if ($Action) {
        & $Action $stage
    }
}

function Complete-IconEditorDevModeTelemetry {
    param(
        [Parameter(Mandatory=$true)][pscustomobject]$Context,
        [string]$Status,
        [psobject]$State,
        [string]$Error
    )
    if (-not $Context.TelemetryPath) { return }
    $dir = Split-Path -Parent $Context.TelemetryPath
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $payload = @{
        status = $Status
        state  = $State
        error  = $Error
    }
    $payload | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $Context.TelemetryPath -Encoding utf8
}

function Invoke-IconEditorRogueCheck {
    param(
        [string]$RepoRoot,
        [string]$Stage,
        [switch]$FailOnRogue,
        [switch]$AutoClose
    )
    $snapshot = Join-Path $env:TEMP ("rogue-{0}.json" -f ([guid]::NewGuid().ToString('n')))
    Set-Content -LiteralPath $snapshot -Value '{}' -Encoding utf8
    return [pscustomobject]@{
        Path = $snapshot
        ExitCode = 0
    }
}

function Get-IconEditorLabVIEWSettleEvents {
    @([pscustomobject]@{ stage = 'stub'; succeeded = $true; durationSeconds = 1 })
}

function Enable-IconEditorDevelopmentMode {
    param(
        [string]$RepoRoot,
        [string]$IconEditorRoot,
        [int[]]$Versions,
        [int[]]$Bitness,
        [string]$Operation
    )
    $Global:DevModeCallLog += [pscustomobject]@{
        Command       = 'Enable'
        RepoRoot      = $RepoRoot
        IconEditorRoot= $IconEditorRoot
        Versions      = $Versions
        Bitness       = $Bitness
        Operation     = $Operation
    }
    return [pscustomobject]@{
        Path      = 'state.json'
        UpdatedAt = '2025-01-01T00:00:00Z'
        Active    = $true
        Verification = [pscustomobject]@{
            Entries = @([pscustomobject]@{
                Version = 2025
                Bitness = 64
                Present = $true
                ContainsIconEditorPath = $true
            })
        }
    }
}
function Disable-IconEditorDevelopmentMode {
    param(
        [string]$RepoRoot,
        [string]$IconEditorRoot,
        [int[]]$Versions,
        [int[]]$Bitness,
        [string]$Operation
    )
    $Global:DevModeCallLog += [pscustomobject]@{
        Command       = 'Disable'
        RepoRoot      = $RepoRoot
        IconEditorRoot= $IconEditorRoot
        Versions      = $Versions
        Bitness       = $Bitness
        Operation     = $Operation
    }
    return [pscustomobject]@{
        Path      = 'state.json'
        UpdatedAt = '2025-01-01T01:00:00Z'
    }
}
'@ | Set-Content -LiteralPath $modulePath -Encoding utf8

            $result = & $script:enableDevModeScript `
                -RepoRoot $repoRoot `
                -IconEditorRoot $iconRoot `
                -Versions 2023,2026 `
                -Bitness 32,64 `
                -Operation 'BuildPackage'
        }
        finally {
            Copy-Item -LiteralPath $backupPath -Destination $modulePath -Force
            Remove-Item -LiteralPath $backupPath -Force
            Remove-Item Env:ICON_EDITOR_FAKE_REPO_ROOT -ErrorAction SilentlyContinue
            Remove-Item Env:ICON_EDITOR_FAKE_ICON_ROOT -ErrorAction SilentlyContinue
        }

        $result.Path | Should -Be 'state.json'
        $expectedEnable = @{
            UpdatedAt = '2025-01-01T00:00:00Z'
            Command   = 'Enable'
            RepoRoot  = $repoRoot
            IconRoot  = $iconRoot
        }
        $result.UpdatedAt | Should -Be $expectedEnable.UpdatedAt
        $Global:DevModeCallLog.Count | Should -Be 1
        $captured = $Global:DevModeCallLog[0]
        $captured.Command | Should -Be $expectedEnable.Command
        $captured.RepoRoot | Should -Be $expectedEnable.RepoRoot
        $captured.IconEditorRoot | Should -Be $expectedEnable.IconRoot
        ($captured.Versions | Sort-Object) | Should -Be @(2023,2026)
        ($captured.Bitness | Sort-Object) | Should -Be @(32,64)
        $captured.Operation | Should -Be 'BuildPackage'
        Remove-Variable -Name DevModeCallLog -Scope Global -ErrorAction SilentlyContinue
    }

    It 'Disable-DevMode.ps1 forwards parameters to IconEditorDevMode' {
        $modulePath = Join-Path $script:repoRoot 'tools/icon-editor/IconEditorDevMode.psm1'
        $backupPath = Join-Path $TestDrive 'IconEditorDevMode.disable.bak'
        Copy-Item -LiteralPath $modulePath -Destination $backupPath -Force
        $Global:DevModeCallLog = @()
        $repoRoot = Join-Path $TestDrive 'repo-disable'
        $iconRoot = Join-Path $repoRoot 'icon'
        New-Item -ItemType Directory -Path $repoRoot,$iconRoot -Force | Out-Null
        $env:ICON_EDITOR_FAKE_REPO_ROOT = $repoRoot
        $env:ICON_EDITOR_FAKE_ICON_ROOT = $iconRoot

        try {
@'
function Resolve-IconEditorRepoRoot {
    if ($env:ICON_EDITOR_FAKE_REPO_ROOT) {
        return (Resolve-Path -LiteralPath $env:ICON_EDITOR_FAKE_REPO_ROOT).Path
    }
    return (Join-Path $env:TEMP 'icon-editor-repo')
}

function Resolve-IconEditorRoot {
    param([string]$RepoRoot)
    if ($env:ICON_EDITOR_FAKE_ICON_ROOT) {
        return (Resolve-Path -LiteralPath $env:ICON_EDITOR_FAKE_ICON_ROOT).Path
    }
    if ($RepoRoot) {
        return (Join-Path $RepoRoot 'icon')
    }
    return $RepoRoot
}

function Initialize-IconEditorDevModeTelemetry {
    param(
        [string]$Mode,
        [string]$RepoRoot,
        [string]$IconEditorRoot,
        [int[]]$Versions,
        [int[]]$Bitness,
        [string]$Operation
    )
    $tmp = Join-Path $env:TEMP ("telemetry-{0}.json" -f ([guid]::NewGuid().ToString('n')))
    return [pscustomobject]@{
        TelemetryPath = $tmp
        TelemetryLatestPath = $tmp
        Telemetry = @{}
    }
}

function Invoke-IconEditorTelemetryStage {
    param(
        [Parameter(Mandatory=$true)][pscustomobject]$Context,
        [string]$Name,
        [int]$ExpectedSeconds,
        [scriptblock]$Action
    )
    $stage = [pscustomobject]@{
        name        = $Name
        stage       = $null
        statePath   = $null
        snapshotPath= $null
        settleEvents= @()
        exitCode    = $null
    }
    if ($Action) {
        & $Action $stage
    }
}

function Complete-IconEditorDevModeTelemetry {
    param(
        [Parameter(Mandatory=$true)][pscustomobject]$Context,
        [string]$Status,
        [psobject]$State,
        [string]$Error
    )
    if (-not $Context.TelemetryPath) { return }
    $dir = Split-Path -Parent $Context.TelemetryPath
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $payload = @{
        status = $Status
        state  = $State
        error  = $Error
    }
    $payload | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $Context.TelemetryPath -Encoding utf8
}

function Invoke-IconEditorRogueCheck {
    param(
        [string]$RepoRoot,
        [string]$Stage,
        [switch]$FailOnRogue,
        [switch]$AutoClose
    )
    $snapshot = Join-Path $env:TEMP ("rogue-{0}.json" -f ([guid]::NewGuid().ToString('n')))
    Set-Content -LiteralPath $snapshot -Value '{}' -Encoding utf8
    return [pscustomobject]@{
        Path = $snapshot
        ExitCode = 0
    }
}

function Get-IconEditorLabVIEWSettleEvents {
    @([pscustomobject]@{ stage = 'stub'; succeeded = $true; durationSeconds = 1 })
}

function Enable-IconEditorDevelopmentMode {
    param(
        [string]$RepoRoot,
        [string]$IconEditorRoot,
        [int[]]$Versions,
        [int[]]$Bitness,
        [string]$Operation
    )
    $Global:DevModeCallLog += [pscustomobject]@{
        Command       = 'Enable'
        RepoRoot      = $RepoRoot
        IconEditorRoot= $IconEditorRoot
        Versions      = $Versions
        Bitness       = $Bitness
        Operation     = $Operation
    }
    return [pscustomobject]@{
        Path      = 'state.json'
        UpdatedAt = '2025-01-01T00:00:00Z'
        Active    = $true
        Verification = [pscustomobject]@{
            Entries = @([pscustomobject]@{
                Version = 2025
                Bitness = 64
                Present = $true
                ContainsIconEditorPath = $true
            })
        }
    }
}
function Disable-IconEditorDevelopmentMode {
    param(
        [string]$RepoRoot,
        [string]$IconEditorRoot,
        [int[]]$Versions,
        [int[]]$Bitness,
        [string]$Operation
    )
    $Global:DevModeCallLog += [pscustomobject]@{
        Command       = 'Disable'
        RepoRoot      = $RepoRoot
        IconEditorRoot= $IconEditorRoot
        Versions      = $Versions
        Bitness       = $Bitness
        Operation     = $Operation
    }
    return [pscustomobject]@{
        Path      = 'state.json'
        UpdatedAt = '2025-01-01T01:00:00Z'
        Active    = $false
        Verification = [pscustomobject]@{
            Entries = @([pscustomobject]@{
                Version = 2025
                Bitness = 64
                Present = $true
                ContainsIconEditorPath = $false
            })
        }
    }
}
'@ | Set-Content -LiteralPath $modulePath -Encoding utf8

            $result = & $script:disableDevModeScript `
                -RepoRoot $repoRoot `
                -IconEditorRoot $iconRoot `
                -Versions 2023 `
                -Bitness 64 `
                -Operation 'BuildPackage'
        }
        finally {
            Copy-Item -LiteralPath $backupPath -Destination $modulePath -Force
            Remove-Item -LiteralPath $backupPath -Force
            Remove-Item Env:ICON_EDITOR_FAKE_REPO_ROOT -ErrorAction SilentlyContinue
            Remove-Item Env:ICON_EDITOR_FAKE_ICON_ROOT -ErrorAction SilentlyContinue
        }

        $result.Path | Should -Be 'state.json'
        $expectedDisable = @{
            UpdatedAt = '2025-01-01T01:00:00Z'
            Command   = 'Disable'
            RepoRoot  = $repoRoot
            IconRoot  = $iconRoot
        }
        $result.UpdatedAt | Should -Be $expectedDisable.UpdatedAt
        $Global:DevModeCallLog.Count | Should -Be 1
        $captured = $Global:DevModeCallLog[0]
        $captured.Command | Should -Be $expectedDisable.Command
        $captured.RepoRoot | Should -Be $expectedDisable.RepoRoot
        $captured.IconEditorRoot | Should -Be $expectedDisable.IconRoot
        $captured.Versions | Should -Be @(2023)
        $captured.Bitness | Should -Be @(64)
        $captured.Operation | Should -Be 'BuildPackage'
        Remove-Variable -Name DevModeCallLog -Scope Global -ErrorAction SilentlyContinue
    }

    AfterAll {
        Restore-PackagingScriptStubs
        Remove-Item Env:ICON_EDITOR_FIXTURE_PATH -ErrorAction SilentlyContinue
        Remove-Item Env:ICON_EDITOR_BASELINE_FIXTURE_PATH -ErrorAction SilentlyContinue
        Remove-Item Env:ICON_EDITOR_BASELINE_MANIFEST_PATH -ErrorAction SilentlyContinue
    }

    It 'Describe-IconEditorFixture.ps1 requires -FixturePath' {
        { & $script:describeScript } | Should -Throw '*FixturePath*'
    }

    It 'Update-IconEditorFixtureReport.ps1 requires -FixturePath' {
        { & $script:updateReportScript } | Should -Throw '*FixturePath*'
    }

    It 'Describe-IconEditorFixture.ps1 produces a summary for a synthetic VIP' {
        $summary = & $script:describeScript -FixturePath $script:fixtureVipPath
        $summary.schema | Should -Be 'icon-editor/fixture-report@v1'
        ($summary.artifacts | Measure-Object).Count | Should -BeGreaterThan 0
        ($summary.fixtureOnlyAssets | Measure-Object).Count | Should -BeGreaterThan 0
    }

    It 'Stage-IconEditorSnapshot.ps1 fails fast when FixturePath missing' {
        { & $script:stageScript `
            -SourcePath (Join-Path $script:repoRoot 'vendor/labview-icon-editor') `
            -StageName 'smoke' `
            -SkipValidate `
            -SkipLVCompare `
            -DryRun } | Should -Throw '*FixturePath*'
    }

    It 'Stage-IconEditorSnapshot.ps1 honors baseline paths' {
        $workspace = Join-Path $TestDrive 'snapshot-workspace'
        $result = & $script:stageScript `
            -SourcePath (Join-Path $script:repoRoot 'vendor/labview-icon-editor') `
            -StageName 'baseline-check' `
            -WorkspaceRoot $workspace `
            -FixturePath $script:fixtureVipPath `
            -BaselineFixture $script:baselineVipPath `
            -BaselineManifest $script:baselineManifestPath `
            -SkipValidate `
            -SkipLVCompare `
            -DryRun

        $result.stageExecuted | Should -BeTrue
        $result.fixturePath | Should -Be (Resolve-Path $script:fixtureVipPath).Path
        $result.baselineFixture | Should -Be (Resolve-Path $script:baselineVipPath).Path
        $result.baselineManifest | Should -Be (Resolve-Path $script:baselineManifestPath).Path
    }

    It 'Invoke-ValidateLocal.ps1 requires FixturePath' {
        { & $script:validateScript `
            -SkipBootstrap `
            -DryRun `
            -SkipLVCompare } | Should -Throw '*FixturePath*'
    }

    It 'Prepare-FixtureViDiffs.ps1 emits requests with a baseline manifest' {
        $resultsRoot = Join-Path $TestDrive 'report-root'
        $reportPath = Join-Path $resultsRoot 'fixture-report.json'
        & $script:updateReportScript `
            -FixturePath $script:fixtureVipPath `
            -ManifestPath (Join-Path $resultsRoot 'fixture-generated-manifest.json') `
            -ResultsRoot $resultsRoot `
            -NoSummary | Out-Null

        $outputDir = Join-Path $TestDrive 'vi-diff-output'
        & $script:prepareScript `
            -ReportPath $reportPath `
            -BaselineManifestPath $script:baselineManifestPath `
            -BaselineFixturePath $script:baselineVipPath `
            -OutputDir $outputDir | Out-Null

        $requestsPath = Join-Path $outputDir 'vi-diff-requests.json'
        Test-Path -LiteralPath $requestsPath | Should -BeTrue
        $requests = Get-Content -LiteralPath $requestsPath -Raw | ConvertFrom-Json -Depth 6
        $requests.count | Should -BeGreaterThan 0
    }

    It 'Render-IconEditorFixtureReport.ps1 includes delta information when baseline manifest env var is set' {
        $resultsRoot = Join-Path $TestDrive 'render-root'
        $reportPath = Join-Path $resultsRoot 'fixture-report.json'
        & $script:updateReportScript `
            -FixturePath $script:fixtureVipPath `
            -ResultsRoot $resultsRoot `
            -NoSummary | Out-Null

        $markdownPath = Join-Path $resultsRoot 'fixture-report.md'
        $env:ICON_EDITOR_BASELINE_MANIFEST_PATH = $script:baselineManifestPath
        & $script:renderScript `
            -ReportPath $reportPath `
            -FixturePath $script:fixtureVipPath `
            -OutputPath $markdownPath | Out-Null

        $content = Get-Content -LiteralPath $markdownPath -Raw
        $content | Should -Match 'Fixture-only manifest delta'
        $content | Should -Match 'Added:'
        Remove-Item Env:ICON_EDITOR_BASELINE_MANIFEST_PATH -ErrorAction SilentlyContinue
    }

    It 'Invoke-VipmCliBuild.ps1 calls rogue detection and close between VIPC targets' -Tag 'VipmSequence' {
        $repoRoot = Join-Path $TestDrive 'vipm-repo'
        $iconRoot = Join-Path $repoRoot 'vendor/labview-icon-editor'
        $applyRoot = Join-Path $iconRoot '.github/actions/apply-vipc'
        $closeRoot = Join-Path $iconRoot '.github/actions/close-labview'

        New-Item -ItemType Directory -Path (Join-Path $repoRoot 'tools') -Force | Out-Null
        New-Item -ItemType Directory -Path $applyRoot -Force | Out-Null
        New-Item -ItemType Directory -Path $closeRoot -Force | Out-Null

        $logPath = Join-Path $TestDrive 'vipm-sequence.log'
        $env:VIPM_TEST_LOG = $logPath

        @'
param([switch]$FailOnRogue)
Add-Content -LiteralPath $env:VIPM_TEST_LOG -Value 'detect'
'@ | Set-Content -LiteralPath (Join-Path $repoRoot 'tools/Detect-RogueLV.ps1') -Encoding utf8

        @'
param(
  [string]$MinimumSupportedLVVersion,
  [string]$SupportedBitness
)
Add-Content -LiteralPath $env:VIPM_TEST_LOG -Value ('close-{0}-{1}' -f $MinimumSupportedLVVersion, $SupportedBitness)
'@ | Set-Content -LiteralPath (Join-Path $closeRoot 'Close_LabVIEW.ps1') -Encoding utf8

        @'
param(
  [string]$MinimumSupportedLVVersion,
  [string]$SupportedBitness,
  [string]$IconEditorRoot,
  [string]$VIP_LVVersion
)
Add-Content -LiteralPath $env:VIPM_TEST_LOG -Value ('apply-{0}-{1}-{2}' -f $SupportedBitness, $MinimumSupportedLVVersion, $VIP_LVVersion)
'@ | Set-Content -LiteralPath (Join-Path $applyRoot 'ApplyVIPC.ps1') -Encoding utf8

        try {
            & (Join-Path $script:repoRoot 'tools/icon-editor/Invoke-VipmCliBuild.ps1') `
                -RepoRoot $repoRoot `
                -IconEditorRoot $iconRoot `
                -SkipSync `
                -SkipBuild | Out-Null
        }
        finally {
            Remove-Item Env:VIPM_TEST_LOG -ErrorAction SilentlyContinue
        }

        Test-Path -LiteralPath $logPath -PathType Leaf | Should -BeTrue
        $log = Get-Content -LiteralPath $logPath

        $log[0] | Should -Be 'detect'
        $applyEntries = $log | Where-Object { $_ -like 'apply-*' }
        $applyEntries.Count | Should -Be 3
        $applyEntries | Should -Contain 'apply-32-2023-2023'
        $applyEntries | Should -Contain 'apply-64-2023-2023'
        $applyEntries | Should -Contain 'apply-64-2026-2026'

        foreach ($entry in $applyEntries) {
            $index = [Array]::IndexOf($log, $entry)
            $log[$index + 1] | Should -Match '^close-'
            $log[$index + 2] | Should -Be 'detect'
        }
    }

    It 'Invoke-VipmCliBuild.ps1 installs vipm and g-cli wrappers during sync' -Tag 'VipmSequence' {
        $repoRoot = Join-Path $TestDrive 'vipm-wrappers'
        $iconRoot = Join-Path $repoRoot 'vendor/labview-icon-editor'
        $syncScript = Join-Path $repoRoot 'tools/icon-editor/Sync-IconEditorFork.ps1'

        New-Item -ItemType Directory -Path (Join-Path $repoRoot 'tools/icon-editor'),$iconRoot -Force | Out-Null
@'
param()
"synced" | Out-Null
'@ | Set-Content -LiteralPath $syncScript -Encoding utf8

        { & (Join-Path $script:repoRoot 'tools/icon-editor/Invoke-VipmCliBuild.ps1') `
            -RepoRoot $repoRoot `
            -IconEditorRoot $iconRoot `
            -SkipVipcApply `
            -SkipBuild `
            -SkipClose `
            -SkipRogueCheck } | Should -Not -Throw

        $wrapperDir = Join-Path $iconRoot 'tools'
        $gcliWrapper = Join-Path $wrapperDir 'GCli.psm1'
        $vipmWrapper = Join-Path $wrapperDir 'Vipm.psm1'

        Test-Path -LiteralPath $gcliWrapper | Should -BeTrue
        Test-Path -LiteralPath $vipmWrapper | Should -BeTrue
        (Get-Content -LiteralPath $gcliWrapper -Raw) | Should -Match 'GCli\.psm1'
        (Get-Content -LiteralPath $vipmWrapper -Raw) | Should -Match 'Vipm\.psm1'
    }

    It 'Invoke-VipmCliBuild.ps1 forwards vipm build arguments to Invoke-IconEditorBuild' -Tag 'VipmSequence' {
        $repoRoot = Join-Path $TestDrive 'vipm-build'
        $iconRoot = Join-Path $repoRoot 'vendor/labview-icon-editor'
        $syncScript = Join-Path $repoRoot 'tools/icon-editor/Sync-IconEditorFork.ps1'
        $buildScript = Join-Path $repoRoot 'tools/icon-editor/Invoke-IconEditorBuild.ps1'
        $recordPath = Join-Path $TestDrive 'vipm-build-record.json'

        New-Item -ItemType Directory -Path (Split-Path -Parent $buildScript),$iconRoot -Force | Out-Null
@'
param()
"noop" | Out-Null
'@ | Set-Content -LiteralPath $syncScript -Encoding utf8

        $env:ICON_EDITOR_BUILD_RECORD = $recordPath
@"
param(
  [string]$IconEditorRoot,
  [string]$ResultsRoot,
  [string]$BuildToolchain,
  [int]$MinimumSupportedLVVersion,
  [int]$PackageMinimumSupportedLVVersion,
  [int]$PackageSupportedBitness,
  [int]$Major,
  [int]$Minor,
  [int]$Patch,
  [int]$Build,
  [switch]$Verbose
)
\$payload = [pscustomobject]@{
  IconEditorRoot = \$IconEditorRoot
  ResultsRoot    = \$ResultsRoot
  BuildToolchain = \$BuildToolchain
  MinimumSupportedLVVersion = \$MinimumSupportedLVVersion
  PackageMinimumSupportedLVVersion = \$PackageMinimumSupportedLVVersion
  PackageSupportedBitness = \$PackageSupportedBitness
  Major = \$Major
  Minor = \$Minor
  Patch = \$Patch
  Build = \$Build
}
\$recordPath = \$env:ICON_EDITOR_BUILD_RECORD
if (-not \$recordPath) { throw 'Missing ICON_EDITOR_BUILD_RECORD env variable.' }
\$payload | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath \$recordPath -Encoding utf8
"@ | Set-Content -LiteralPath $buildScript -Encoding utf8

        try {
            { & (Join-Path $script:repoRoot 'tools/icon-editor/Invoke-VipmCliBuild.ps1') `
                -RepoRoot $repoRoot `
                -IconEditorRoot $iconRoot `
                -SkipVipcApply `
                -SkipClose `
                -SkipRogueCheck } | Should -Not -Throw
        } finally {
            Remove-Item Env:ICON_EDITOR_BUILD_RECORD -ErrorAction SilentlyContinue
        }

        Test-Path -LiteralPath $recordPath | Should -BeTrue
        $record = Get-Content -LiteralPath $recordPath -Raw | ConvertFrom-Json
        $record.BuildToolchain | Should -Be 'vipm'
        $record.MinimumSupportedLVVersion | Should -Be 2023
        $record.PackageMinimumSupportedLVVersion | Should -Be 2026
        $record.PackageSupportedBitness | Should -Be 64
    }

    It 'Simulate-IconEditorBuild.ps1 produces dry-run artifacts' {
        $resultsRoot = Join-Path $TestDrive 'simulate'
        $vipDiffDir = Join-Path $resultsRoot 'vip-diff'
        $requestsPath = Join-Path $vipDiffDir 'vi-diff-requests.json'
        $expectedVersion = [pscustomobject]@{
            major = 1
            minor = 5
            patch = 0
            build = 0
            commit = 'unit-test'
        }

        & $script:simulateScript `
            -FixturePath $script:fixtureVipPath `
            -ResultsRoot $resultsRoot `
            -VipDiffOutputDir $vipDiffDir `
            -VipDiffRequestsPath $requestsPath `
            -ExpectedVersion $expectedVersion `
            -SkipResourceOverlay | Out-Null

        Test-Path -LiteralPath (Join-Path $resultsRoot 'package-smoke-summary.json') | Should -BeTrue
        Test-Path -LiteralPath $requestsPath | Should -BeTrue
        $requestJson = Get-Content -LiteralPath $requestsPath -Raw | ConvertFrom-Json -Depth 6
        $requestJson.count | Should -BeGreaterThan 0
    }

    Context 'Invoke-ValidateLocal SkipLVCompare integration' {
        BeforeAll {
            Restore-PackagingScriptStubs
            $script:skipLvCompareLog = Join-Path $TestDrive 'skip-lvcompare-log.json'
            $env:PACKAGING_DIFF_LOG = $script:skipLvCompareLog

            Install-PackagingScriptStub -TargetPath $script:describeScript -Content $describeStub
            Install-PackagingScriptStub -TargetPath $script:prepareScript -Content $prepareStub
            Install-PackagingScriptStub -TargetPath $script:renderScript -Content $renderStub
            Install-PackagingScriptStub -TargetPath $script:simulateScript -Content $simulateStub
            Install-PackagingScriptStub -TargetPath (Join-Path $script:repoRoot 'tools/icon-editor/Invoke-FixtureViDiffs.ps1') -Content $invokeDiffsStub
        }

        AfterAll {
            Restore-PackagingScriptStubs
            Remove-Item Env:PACKAGING_DIFF_LOG -ErrorAction SilentlyContinue
        }

        It 'Invoke-ValidateLocal.ps1 performs dry-run compare when SkipLVCompare is set' -Tag 'SkipLVCompare' {
            $resultsRoot = Join-Path $TestDrive 'validate-local-skip'
            if (Test-Path -LiteralPath $resultsRoot) {
                Remove-Item -LiteralPath $resultsRoot -Recurse -Force
            }

            { & $script:validateScript `
                -FixturePath $script:fixtureVipPath `
                -BaselineFixture $script:baselineVipPath `
                -BaselineManifest $script:baselineManifestPath `
                -ResultsRoot $resultsRoot `
                -SkipLVCompare `
                -SkipBootstrap `
                -DryRun } | Should -Not -Throw

            $requestsPath = Join-Path (Join-Path $resultsRoot 'vi-diff') 'vi-diff-requests.json'
            $summaryPath = Join-Path (Join-Path $resultsRoot 'vi-diff-captures') 'vi-comparison-summary.json'
            $reportPath = Join-Path (Join-Path $resultsRoot 'vi-diff-captures') 'vi-comparison-report.md'

            Test-Path -LiteralPath $requestsPath | Should -BeTrue
            Test-Path -LiteralPath $summaryPath | Should -BeTrue
            Test-Path -LiteralPath $reportPath | Should -BeTrue

            Test-Path -LiteralPath $script:skipLvCompareLog | Should -BeTrue
            $log = Get-Content -LiteralPath $script:skipLvCompareLog -Raw | ConvertFrom-Json -Depth 6
            $log.dryRun | Should -BeTrue
            $log.requestsPath | Should -Match 'vi-diff-requests.json'
            $log.capturesRoot | Should -Match 'vi-diff-captures'
            $log.summaryPath | Should -Match 'vi-comparison-summary.json'

            $reportContent = Get-Content -LiteralPath $reportPath -Raw
            $reportContent | Should -Match '## VI Comparison Report'
            $reportContent | Should -Match 'dry-run'
        }
    }
}


