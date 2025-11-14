#requires -Version 7.0

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path

Describe 'Prepare_LabVIEW_source.ps1' -Tag 'tools','icon-editor','prepare' {
    BeforeAll {
        $script:prepareScriptPath = Join-Path $repoRoot 'vendor/labview-icon-editor/.github/actions/prepare-labview-source/Prepare_LabVIEW_source.ps1'
        if (-not (Test-Path -LiteralPath $script:prepareScriptPath -PathType Leaf)) {
            throw "Prepare script not found at $script:prepareScriptPath"
        }
        $script:prepareScriptContent = Get-Content -LiteralPath $script:prepareScriptPath -Raw
    }

    It 'places Localhost.LibraryPaths ahead of the .lvproj path and includes the Editor Packed Library build spec' {
        $script:prepareScriptContent | Should -Match 'Localhost\.LibraryPaths.*\$escapedLibraryPaths.*\$escapedLabVIEWProjectPath'
        $script:prepareScriptContent | Should -Match '"Editor Packed Library"'
    }
}

