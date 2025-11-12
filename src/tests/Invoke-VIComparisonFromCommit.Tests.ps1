Describe 'Invoke-VIComparisonFromCommit.ps1' -Tag 'IconEditor','LVCompare','Unit' {
    BeforeAll {
        $script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
        $script:scriptPath = Join-Path $script:repoRoot 'src/tools/icon-editor/Invoke-VIComparisonFromCommit.ps1'
        $script:stubRecords = @()
        $script:testRepos = New-Object System.Collections.Generic.List[string]

        function Script:Install-ScriptStub {
            param(
                [Parameter(Mandatory)][string]$RelativePath,
                [Parameter(Mandatory)][string]$Content
            )

            $target = Join-Path $script:repoRoot $RelativePath
            if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
                throw "Cannot stub missing script: $RelativePath"
            }

            $backup = Join-Path $TestDrive ("stub-{0}.ps1" -f ([guid]::NewGuid().ToString('n')))
            Copy-Item -LiteralPath $target -Destination $backup -Force
            Set-Content -LiteralPath $target -Value $Content -Encoding utf8
            $script:stubRecords += [pscustomobject]@{ Target = $target; Backup = $backup }
        }

        function Script:Restore-ScriptStubs {
            if (-not $script:stubRecords) { return }
            foreach ($entry in $script:stubRecords) {
                Copy-Item -LiteralPath $entry.Backup -Destination $entry.Target -Force
                Remove-Item -LiteralPath $entry.Backup -Force -ErrorAction SilentlyContinue
            }
            $script:stubRecords = @()
        }

        function Script:New-TestRepo {
            param([switch]$WithParent)

            $repoPath = Join-Path $TestDrive ("repo-{0}" -f ([guid]::NewGuid().ToString('n')))
            git init $repoPath | Out-Null
            git -C $repoPath config user.email "test@example.com" | Out-Null
            git -C $repoPath config user.name "IconEditor CI" | Out-Null

            $viDir = Join-Path $repoPath 'src/VIs'
            New-Item -ItemType Directory -Path $viDir -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $viDir 'Icon.vi') -Value 'base' -Encoding utf8
            git -C $repoPath add . | Out-Null
            git -C $repoPath commit -m 'base' | Out-Null

            if ($WithParent) {
                Set-Content -LiteralPath (Join-Path $viDir 'Icon.vi') -Value 'head' -Encoding utf8
                git -C $repoPath commit -am 'head' | Out-Null
            }

            $head = (git -C $repoPath rev-parse HEAD).Trim()
            $parent = $null
            try { $parent = (git -C $repoPath rev-parse HEAD^).Trim() } catch {}

            $script:testRepos.Add($repoPath) | Out-Null

            [pscustomobject]@{
                Path   = $repoPath
                Head   = $head
                Parent = $parent
            }
        }
    }

    AfterEach {
        foreach ($name in 'TEST_VICOMMIT_FILES','TEST_VICOMMIT_STAGE_LOG','TEST_VICOMMIT_COMPARE_LOG') {
            Remove-Item ("Env:{0}" -f $name) -ErrorAction SilentlyContinue
        }
        Restore-ScriptStubs
        foreach ($repoPath in $script:testRepos) {
            if (Test-Path -LiteralPath $repoPath) {
                Remove-Item -LiteralPath $repoPath -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        $script:testRepos.Clear()
    }

    AfterAll {
        Restore-ScriptStubs
    }

    It 'returns early when commit has no parent' {
        $repo = New-TestRepo
        $labviewExe = Join-Path $TestDrive 'LabVIEW-2025.exe'
        Set-Content -LiteralPath $labviewExe -Value 'stub' -Encoding utf8

        $result = & $script:scriptPath `
            -Commit $repo.Head `
            -RepoPath $repo.Path `
            -SkipSync `
            -LabVIEWExePath $labviewExe

        $result | Should -Not -BeNullOrEmpty
        $result.staged | Should -BeFalse
        $result.stageSummary | Should -BeNullOrEmpty
        $result.parent | Should -BeNullOrEmpty
    }

    It 'stages snapshot and honors SkipLVCompare when files remain after filtering' {
        Install-ScriptStub 'src/tools/icon-editor/Prepare-OverlayFromRepo.ps1' @'
param(
  [string]$RepoPath,
  [string]$BaseRef,
  [string]$HeadRef,
  [string]$OverlayRoot,
  [switch]$Force
)
if (-not (Test-Path -LiteralPath $OverlayRoot -PathType Container)) {
  New-Item -ItemType Directory -Path $OverlayRoot -Force | Out-Null
}
$list = if ($env:TEST_VICOMMIT_FILES) { $env:TEST_VICOMMIT_FILES -split ';' } else { @() }
foreach ($item in $list) {
  if (-not $item) { continue }
  $dest = Join-Path $OverlayRoot ($item -replace '/', [System.IO.Path]::DirectorySeparatorChar)
  $dir = Split-Path -Parent $dest
  if (-not (Test-Path -LiteralPath $dir -PathType Container)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
  }
  Set-Content -LiteralPath $dest -Value 'HEAD' -Encoding utf8
}
[pscustomobject]@{
  overlayRoot = $OverlayRoot
  files       = @($list)
}
'@

        Install-ScriptStub 'src/tools/icon-editor/Stage-IconEditorSnapshot.ps1' @'
param(
  [string]$SourcePath,
  [string]$ResourceOverlayRoot,
  [string]$StageName,
  [string]$WorkspaceRoot,
  [switch]$SkipValidate,
  [switch]$SkipLVCompare,
  [switch]$DryRun,
  [switch]$SkipBootstrapForValidate
)
if (-not $StageName) { $StageName = 'auto-stage' }
$root = Join-Path $WorkspaceRoot $StageName
New-Item -ItemType Directory -Path $root -Force | Out-Null
if ($env:TEST_VICOMMIT_STAGE_LOG) {
  [pscustomobject]@{
    StageName     = $StageName
    SkipLVCompare = $SkipLVCompare.IsPresent
    DryRun        = $DryRun.IsPresent
    WorkspaceRoot = $WorkspaceRoot
  } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $env:TEST_VICOMMIT_STAGE_LOG -Encoding utf8
}
[pscustomobject]@{
  stageRoot       = $root
  resourceOverlay = $ResourceOverlayRoot
}
'@

        Install-ScriptStub 'src/tools/Run-HeadlessCompare.ps1' @'
param(
  [string]$BaseVi,
  [string]$HeadVi,
  [string]$OutputRoot,
  [switch]$UseRawPaths,
  [string]$WarmupMode,
  [string]$NoiseProfile,
  [int]$TimeoutSeconds,
  [string]$LabVIEWExePath
)
if (-not (Test-Path -LiteralPath $OutputRoot -PathType Container)) {
  New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
}
if ($env:TEST_VICOMMIT_COMPARE_LOG) {
  $entry = [pscustomobject]@{
    BaseVi     = $BaseVi
    HeadVi     = $HeadVi
    UseRawPaths= $UseRawPaths.IsPresent
  } | ConvertTo-Json -Compress
  Add-Content -LiteralPath $env:TEST_VICOMMIT_COMPARE_LOG -Value $entry
}
'@

        $repo = New-TestRepo -WithParent
        $labviewExe = Join-Path $TestDrive 'LabVIEW-2025.exe'
        Set-Content -LiteralPath $labviewExe -Value 'stub' -Encoding utf8

        $env:TEST_VICOMMIT_FILES = 'src/VIs/Icon.vi'
        $env:TEST_VICOMMIT_STAGE_LOG = Join-Path $TestDrive 'stage-log.json'
        $env:TEST_VICOMMIT_COMPARE_LOG = Join-Path $TestDrive 'compare.log'

        $result = & $script:scriptPath `
            -Commit $repo.Head `
            -RepoPath $repo.Path `
            -SkipSync `
            -SkipValidate `
            -SkipBootstrapForValidate `
            -SkipLVCompare `
            -DryRun `
            -IncludePaths 'src/VIs/Icon.vi' `
            -LabVIEWExePath $labviewExe

        $result.staged | Should -BeTrue
        $result.files | Should -Be @('src/VIs/Icon.vi')

        Test-Path -LiteralPath $env:TEST_VICOMMIT_STAGE_LOG | Should -BeTrue
        $stageLog = Get-Content -LiteralPath $env:TEST_VICOMMIT_STAGE_LOG -Raw | ConvertFrom-Json
        $stageLog.SkipLVCompare | Should -BeTrue
        $stageLog.DryRun | Should -BeTrue

        Test-Path -LiteralPath $env:TEST_VICOMMIT_COMPARE_LOG | Should -BeTrue
        $compareEntry = Get-Content -LiteralPath $env:TEST_VICOMMIT_COMPARE_LOG -Raw | ConvertFrom-Json
        $compareEntry.UseRawPaths | Should -BeTrue
    }
}
