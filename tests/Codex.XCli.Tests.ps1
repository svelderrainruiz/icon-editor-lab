Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function global:Invoke-XCliWorkflowLocal {
    param(
        [Parameter(Mandatory)][string]$HelperPath,
        [Parameter(Mandatory)][string]$Workflow,
        [Parameter(Mandatory)][hashtable]$Request
    )
    $requestPath = Join-Path ([System.IO.Path]::GetTempPath()) ("xcli-request-{0}.json" -f ([guid]::NewGuid().ToString('n')))
    $Request | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $requestPath -Encoding UTF8
    $output = & pwsh -NoLogo -NoProfile -File $HelperPath -Workflow $Workflow -RequestPath $requestPath 2>&1
    $exitCode = $LASTEXITCODE
    $outputLines = if ($null -ne $output) { @($output) } else { @() }
    return [pscustomobject]@{
        ExitCode = $exitCode
        Output   = $outputLines
    }
}

function global:Get-XCliResponseObject {
    param([Parameter(Mandatory)][string[]]$Output)
    if (-not $Output) { return $null }
    for ($start = $Output.Length - 1; $start -ge 0; $start--) {
        if ($Output[$start] -notmatch '{') {
            continue
        }
        $builder = New-Object System.Collections.Generic.List[string]
        $depth = 0
        for ($idx = $start; $idx -lt $Output.Length; $idx++) {
            $line = $Output[$idx]
            $builder.Add($line)
            $depth += ([regex]::Matches($line, '{').Count)
            $depth -= ([regex]::Matches($line, '}').Count)
            if ($depth -le 0 -and $line -match '}') {
                $json = [string]::Join([Environment]::NewLine, $builder)
                try {
                    $parsed = $json | ConvertFrom-Json -Depth 12
                    if ($parsed -and $parsed.PSObject.Properties['Schema']) {
                        return $parsed
                    }
                } catch {
                    break
                }
            }
        }
    }
    return $null
}

function global:New-StubRepoPath {
    param([Parameter(Mandatory)][string]$BasePath)
    New-Item -ItemType Directory -Path $BasePath -Force | Out-Null
    return (Resolve-Path $BasePath).ProviderPath
}

function global:New-StubScript {
    param(
        [Parameter(Mandatory)][string]$FullPath,
        [Parameter(Mandatory)][string]$Content
    )
    $dir = Split-Path -Parent $FullPath
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    Set-Content -LiteralPath $FullPath -Value $Content -Encoding UTF8
    return $FullPath
}

Describe 'x-cli workflow orchestration' -Tag 'xcli','slow' {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
        $script:HelperPath = Join-Path $script:RepoRoot 'tools/codex/Invoke-XCliWorkflow.ps1'
    }

    Context 'vi-compare-run (dry-run)' {
        It 'emits suppression metadata in the response JSON' {
            $request = [ordered]@{
                repoRoot             = $script:RepoRoot
                scenarioPath         = 'scenarios/sample/vi-diff-requests.json'
                outputRoot           = Join-Path $script:RepoRoot '.tmp-tests/vi-compare-replays/codex-test'
                bundleOutputDirectory = '.tmp-tests/vi-compare-bundles'
                labVIEWExePath       = 'C:\nonexistent\LabVIEW.exe'
                noiseProfile         = 'full'
                dryRun               = $true
                skipBundle           = $true
            }

            $result = Invoke-XCliWorkflowLocal -HelperPath $script:HelperPath -Workflow 'vi-compare-run' -Request $request
            $result.ExitCode | Should -Be 0

            $outputLines = @($result.Output | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            $response = Get-XCliResponseObject -Output $outputLines
            $response | Should -Not -BeNullOrEmpty
            $response.Schema | Should -Be 'icon-editor/vi-compare-run@v1'
            $response.DryRun | Should -BeTrue
            $response.Summary.suppression.noiseProfile | Should -Be 'full'
        }
    }

    Context 'vi-analyzer-run (missing CLI)' {
        It 'fails with a clear LabVIEWCLI missing error' {
            $stubRoot = New-StubRepoPath -BasePath (Join-Path $TestDrive 'vi-analyzer')
            $configPath = Join-Path $stubRoot 'src/configs/sample.viancfg'
            New-Item -ItemType Directory -Path (Split-Path -Parent $configPath) -Force | Out-Null
            Set-Content -LiteralPath $configPath -Value 'analysis' -Encoding UTF8

            $scriptBody = @'
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ConfigPath,
    [Parameter(Mandatory)][string]$OutputRoot,
    [Parameter(Mandatory)][string]$Label,
    [string]$LabVIEWCLIPath
)
if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
    throw "ConfigPath not found: $ConfigPath"
}
if (-not $LabVIEWCLIPath -or -not (Test-Path -LiteralPath $LabVIEWCLIPath -PathType Leaf)) {
    throw "LabVIEWCLI.exe not found at $LabVIEWCLIPath"
}
$runDir = Join-Path $OutputRoot $Label
New-Item -ItemType Directory -Path $runDir -Force | Out-Null
$result = [pscustomobject]@{ schema = 'icon-editor/vi-analyzer@v1'; exitCode = 0 }
$result | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $runDir 'vi-analyzer.json') -Encoding UTF8
'@
            New-StubScript -FullPath (Join-Path $stubRoot 'src/tools/icon-editor/Invoke-VIAnalyzer.ps1') -Content $scriptBody

            $request = [ordered]@{
                repoRoot      = $stubRoot
                configPath    = 'src/configs/sample.viancfg'
                outputRoot    = Join-Path $stubRoot '.tmp-tests/vi-analyzer/codex-test'
                labVIEWCLIPath = 'C:\nonexistent\LabVIEWCLI.exe'
            }

            $result = Invoke-XCliWorkflowLocal -HelperPath $script:HelperPath -Workflow 'vi-analyzer-run' -Request $request
            $result.ExitCode | Should -Not -Be 0
            ($result.Output -join "`n") | Should -Match 'LabVIEWCLI\.exe not found'
        }
    }

    Context 'vipm-apply-vipc (stub workspace)' {
        It 'passes workspace arguments to the replay script' {
            $stubRoot = New-StubRepoPath -BasePath (Join-Path $TestDrive 'vipm-apply')
            $vipcRelative = '.github/actions/apply-vipc/runner_dependencies.vipc'
            $vipcFull = Join-Path $stubRoot $vipcRelative
            New-Item -ItemType Directory -Path (Split-Path -Parent $vipcFull) -Force | Out-Null
            Set-Content -LiteralPath $vipcFull -Value 'stub vipc bytes' -Encoding UTF8

            $scriptBody = @'
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Workspace,
    [Parameter(Mandatory)][string]$VipcPath,
    [string]$MinimumSupportedLVVersion,
    [string]$VipLabVIEWVersion,
    [int]$SupportedBitness,
    [string]$Toolchain,
    [string]$JobName,
    [switch]$SkipExecution
)
$log = Join-Path $Workspace 'vipm-apply-log.json'
[pscustomobject]@{
    workspace     = $Workspace
    vipcPath      = $VipcPath
    skipExecution = [bool]$SkipExecution
    toolchain     = $Toolchain
} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $log -Encoding UTF8
'@
            New-StubScript -FullPath (Join-Path $stubRoot 'src/tools/icon-editor/Replay-ApplyVipcJob.ps1') -Content $scriptBody

            $request = [ordered]@{
                repoRoot     = $stubRoot
                workspace    = $stubRoot
                vipcPath     = $vipcRelative
                skipExecution = $true
                jobName      = 'Apply VIPC Dependencies'
            }

            $result = Invoke-XCliWorkflowLocal -HelperPath $script:HelperPath -Workflow 'vipm-apply-vipc' -Request $request
            $result.ExitCode | Should -Be 0
            $logPath = Join-Path $stubRoot 'vipm-apply-log.json'
            Test-Path -LiteralPath $logPath | Should -BeTrue
            $log = Get-Content -LiteralPath $logPath | ConvertFrom-Json
            [bool]$log.skipExecution | Should -BeTrue
            $log.vipcPath | Should -Match 'runner_dependencies\.vipc$'
        }
    }

    Context 'vipm-build-vip (stub workspace)' {
        It 'invokes the replay script with release notes path' {
            $stubRoot = New-StubRepoPath -BasePath (Join-Path $TestDrive 'vipm-build')
            $releaseNotes = Join-Path $stubRoot 'Tooling/deployment/release_notes.md'
            New-Item -ItemType Directory -Path (Split-Path -Parent $releaseNotes) -Force | Out-Null
            Set-Content -LiteralPath $releaseNotes -Value 'stub release notes' -Encoding UTF8

            $scriptBody = @'
[CmdletBinding()]
param(
    [string]$Workspace,
    [string]$ReleaseNotesPath,
    [switch]$SkipReleaseNotes,
    [switch]$SkipVipbUpdate,
    [switch]$SkipBuild,
    [switch]$CloseLabVIEW,
    [switch]$DownloadArtifacts,
    [string]$BuildToolchain,
    [string]$BuildProvider,
    [string]$JobName,
    [string]$RunId,
    [string]$LogPath
)
$log = Join-Path $Workspace 'vipm-build-log.txt'
"releaseNotes=$ReleaseNotesPath" | Set-Content -LiteralPath $log -Encoding UTF8
'@
            New-StubScript -FullPath (Join-Path $stubRoot 'src/tools/icon-editor/Replay-BuildVipJob.ps1') -Content $scriptBody

            $request = [ordered]@{
                repoRoot          = $stubRoot
                workspace         = $stubRoot
                releaseNotesPath  = 'Tooling/deployment/release_notes.md'
                skipReleaseNotes  = $true
                skipVipbUpdate    = $true
                skipBuild         = $true
                buildToolchain    = 'g-cli'
            }

            $result = Invoke-XCliWorkflowLocal -HelperPath $script:HelperPath -Workflow 'vipm-build-vip' -Request $request
            $result.ExitCode | Should -Be 0
            $logPath = Join-Path $stubRoot 'vipm-build-log.txt'
            Test-Path -LiteralPath $logPath | Should -BeTrue
            (Get-Content -LiteralPath $logPath) | Should -Match 'releaseNotes=.*Tooling[\\/]+deployment[\\/]+release_notes\.md'
        }
    }

    Context 'vipmcli-build (stub invocation)' {
        It 'routes arguments to Invoke-VipmCliBuild' {
            $stubRoot = New-StubRepoPath -BasePath (Join-Path $TestDrive 'vipmcli-build')
            $iconEditorRoot = Join-Path $stubRoot 'vendor/icon-editor'
            New-Item -ItemType Directory -Path $iconEditorRoot -Force | Out-Null

            $scriptBody = @'
[CmdletBinding()]
param(
    [string]$RepoRoot,
    [string]$IconEditorRoot,
    [switch]$SkipSync,
    [switch]$SkipVipcApply,
    [switch]$SkipBuild,
    [switch]$SkipRogueCheck,
    [switch]$SkipClose,
    [string]$ResultsRoot
)
$log = Join-Path $RepoRoot 'vipmcli-build-log.json'
[pscustomobject]@{
    repoRoot       = $RepoRoot
    iconEditorRoot = $IconEditorRoot
    skipBuild      = [bool]$SkipBuild
    resultsRoot    = $ResultsRoot
} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $log -Encoding UTF8
'@
            New-StubScript -FullPath (Join-Path $stubRoot 'src/tools/icon-editor/Invoke-VipmCliBuild.ps1') -Content $scriptBody

            $request = [ordered]@{
                repoRoot      = $stubRoot
                iconEditorRoot = $iconEditorRoot
                skipSync      = $true
                skipVipcApply = $true
                skipBuild     = $true
                skipRogueCheck = $true
                skipClose      = $true
                resultsRoot   = Join-Path $stubRoot 'results'
            }

            $result = Invoke-XCliWorkflowLocal -HelperPath $script:HelperPath -Workflow 'vipmcli-build' -Request $request
            $result.ExitCode | Should -Be 0
            $logPath = Join-Path $stubRoot 'vipmcli-build-log.json'
            Test-Path -LiteralPath $logPath | Should -BeTrue
            $log = Get-Content -LiteralPath $logPath | ConvertFrom-Json
            [bool]$log.skipBuild | Should -BeTrue
            $log.iconEditorRoot | Should -Match 'vendor\\icon-editor$'
        }
    }

    Context 'ppl-build (stub icon-editor root)' {
        It 'returns a JSON summary per bitness' {
            $iconEditorRoot = New-StubRepoPath -BasePath (Join-Path $TestDrive 'icon-editor-root')
            $buildScript = @'
[CmdletBinding()]
param(
    [int]$MinimumSupportedLVVersion,
    [string]$SupportedBitness,
    [string]$IconEditorRoot,
    [int]$Major,
    [int]$Minor,
    [int]$Patch,
    [int]$Build,
    [string]$Commit
)
Write-Host ("[stub] building {0}-bit PPL" -f $SupportedBitness)
'@
            New-StubScript -FullPath (Join-Path $iconEditorRoot '.github/actions/build-lvlibp/Build_lvlibp.ps1') -Content $buildScript

            $request = [ordered]@{
                repoRoot              = $script:RepoRoot
                iconEditorRoot        = $iconEditorRoot
                minimumSupportedLVVersion = 2025
                major = 1
                minor = 4
                patch = 1
                build = 25001
                commit = 'local'
                bitnessTargets = @('32','64')
            }

            $result = Invoke-XCliWorkflowLocal -HelperPath $script:HelperPath -Workflow 'ppl-build' -Request $request
            $result.ExitCode | Should -Be 0
            $outputLines = @($result.Output | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            $response = Get-XCliResponseObject -Output $outputLines
            $response | Should -Not -BeNullOrEmpty
            $response.Schema | Should -Be 'icon-editor/ppl-build@v1'
            $response.Runs.Length | Should -Be 2
            ($response.Runs | ForEach-Object { $_.ExitCode }) | ForEach-Object { $_ | Should -Be 0 }
        }
    }
}
