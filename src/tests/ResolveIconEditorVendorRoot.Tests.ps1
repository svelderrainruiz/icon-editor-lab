param()

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..' '..')
$resolver = Join-Path $repoRoot 'src/tools/icon-editor/Resolve-IconEditorVendorRoot.ps1'

Describe 'Resolve-IconEditorVendorRoot' {
    It 'resolves vendor root from config placeholder' {
        $workspace = Join-Path $TestDrive 'repo-config'
        New-Item -ItemType Directory -Path (Join-Path $workspace 'configs') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $workspace 'vendor/custom') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $workspace 'configs/icon-editor-vendor.json') -Value '{ "vendorRoot": "${workspaceFolder}/vendor/custom" }'

        $resolved = & $resolver -Workspace $workspace
        $resolved | Should -Be (Join-Path $workspace 'vendor/custom')
    }

    It 'falls back to scanning vendor directory' {
        $workspace = Join-Path $TestDrive 'repo-scan'
        New-Item -ItemType Directory -Path (Join-Path $workspace 'vendor/labview-icon-editor/Tooling/deployment') -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $workspace 'vendor/labview-icon-editor/Tooling/deployment/NI_Icon_editor.vipb') | Out-Null

        $resolved = & $resolver -Workspace $workspace
        $resolved | Should -Be (Join-Path $workspace 'vendor/labview-icon-editor')
    }
}
