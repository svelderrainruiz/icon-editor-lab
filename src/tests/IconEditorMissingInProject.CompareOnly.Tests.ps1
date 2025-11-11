[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Low')]
param(
  [Parameter()][ValidateSet('2021','2023','2025')][string]$LabVIEWVersion = '2023',
  [Parameter()][ValidateSet(32,64)][int]$Bitness = 64,
  [Parameter()][ValidateNotNullOrEmpty()][string]$Workspace = (Get-Location).Path,
  [Parameter()][int]$TimeoutSec = 600
)
#Requires -Version 7.0
#Requires -Modules Pester

Describe 'MissingInProject compare-only suite' -Tag 'IconEditor','Integration','MissingInProject','CompareOnly' {
    $script:repoRoot = $null
    $script:projectFile = $null
    $script:enableDevScript = $null
    $script:disableDevScript = $null
    $script:invokeMissingScript = $null

    $cases = @(
        @{ Version = 2021; Bitness = 32 }
        @{ Version = 2021; Bitness = 64 }
    )

    try {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
        Import-Module (Join-Path $repoRoot 'tools' 'VendorTools.psm1') -Force
        $missing = 0
        foreach ($c in $cases) {
            $exe = $null
            try { $exe = Find-LabVIEWVersionExePath -Version ([int]$c.Version) -Bitness ([int]$c.Bitness) } catch { $exe = $null }
            if (-not $exe) { $missing++ }
        }
        if ($missing -gt 0) {
            Write-Host "Skipping compare-only MissingInProject suite: LabVIEW 2021 (32/64) not available." -ForegroundColor Yellow
            return
        }
    } catch {
        Write-Host "Skipping compare-only MissingInProject suite: vendor tool resolution failed ($($_.Exception.Message))." -ForegroundColor Yellow
        return
    }

    BeforeAll {
        $script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
        $script:projectFile = Join-Path -Path $script:repoRoot -ChildPath 'vendor\icon-editor\lv_icon_editor.lvproj'
        $script:enableDevScript  = Join-Path -Path $script:repoRoot -ChildPath 'tools\icon-editor\Enable-DevMode.ps1'
        $script:disableDevScript = Join-Path -Path $script:repoRoot -ChildPath 'tools\icon-editor\Disable-DevMode.ps1'
        $script:invokeMissingScript = Join-Path -Path $script:repoRoot -ChildPath '.github\actions\missing-in-project\Invoke-MissingInProjectCLI.ps1'

        Test-Path -LiteralPath $script:projectFile | Should -BeTrue
        Test-Path -LiteralPath $script:enableDevScript | Should -BeTrue
        Test-Path -LiteralPath $script:disableDevScript | Should -BeTrue
        Test-Path -LiteralPath $script:invokeMissingScript | Should -BeTrue

        $env:MIP_REPO_ROOT = $repoRoot
        $env:MIP_SKIP_DEVMODE = '1'
        Remove-Item Env:ICON_EDITOR_SKIP_WAIT_FOR_LABVIEW_EXIT -ErrorAction SilentlyContinue
    }

    AfterAll {
        Remove-Item Env:MIP_REPO_ROOT, Env:MIP_SKIP_DEVMODE -ErrorAction SilentlyContinue
        Remove-Item Env:ICON_EDITOR_SKIP_WAIT_FOR_LABVIEW_EXIT -ErrorAction SilentlyContinue
    }

    Context 'LabVIEW compare gate' {
        It "passes MissingInProject when dev mode is enabled (LabVIEW <Version> <Bitness>-bit)" -TestCases $cases {
            param([int]$Version, [int]$Bitness)

            { & $script:enableDevScript -Versions $Version -Bitness $Bitness -Operation BuildPackage } | Should -Not -Throw

            Push-Location $script:repoRoot
            try {
                & $script:invokeMissingScript -LVVersion $Version -Arch $Bitness -ProjectFile $script:projectFile
                $LASTEXITCODE | Should -Be 0
            }
            finally {
                Pop-Location
                try { & $script:disableDevScript -Versions $Version -Bitness $Bitness -Operation BuildPackage | Out-Null } catch {}
            }
        }
    }
}
