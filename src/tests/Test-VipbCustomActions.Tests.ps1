param()

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..' '..')
$guardScript = Join-Path $repoRoot 'src/tools/icon-editor/Test-VipbCustomActions.ps1'
$vipbPath = Join-Path $repoRoot '.github/actions/build-vi-package/NI_Icon_editor.vipb'
$requiredActionFiles = @(
    'VIP_Pre-Install Custom Action.vi',
    'VIP_Post-Install Custom Action.vi',
    'VIP_Pre-Uninstall Custom Action.vi',
    'VIP_Post-Uninstall Custom Action.vi'
)

function New-VipbSandbox {
    param(
        [Parameter(Mandatory)][string]$Root
    )

    $vipbDir = Join-Path $Root '.github/actions/build-vi-package'
    New-Item -ItemType Directory -Path $vipbDir -Force | Out-Null
    Copy-Item -LiteralPath $vipbPath -Destination (Join-Path $vipbDir 'NI_Icon_editor.vipb') -Force
    return $vipbDir
}

Describe 'Test-VipbCustomActions guard' {
    It 'passes when required custom action files exist' {
        $sandboxRoot = Join-Path $TestDrive 'guard-pass'
        $vipbDir = New-VipbSandbox -Root $sandboxRoot
        foreach ($file in $requiredActionFiles) {
            New-Item -ItemType File -Path (Join-Path $vipbDir $file) -Force | Out-Null
        }

        $vipbCopy = Join-Path $vipbDir 'NI_Icon_editor.vipb'
        { & $guardScript -VipbPath $vipbCopy -Workspace $sandboxRoot } | Should -Not -Throw
    }

    It 'fails when a required custom action is missing' {
        $sandboxRoot = Join-Path $TestDrive 'guard-missing'
        $vipbDir = New-VipbSandbox -Root $sandboxRoot
        foreach ($file in $requiredActionFiles | Select-Object -Skip 1) {
            New-Item -ItemType File -Path (Join-Path $vipbDir $file) -Force | Out-Null
        }

        $vipbCopy = Join-Path $vipbDir 'NI_Icon_editor.vipb'
        { & $guardScript -VipbPath $vipbCopy -Workspace $sandboxRoot } | Should -Throw
    }

    It 'fails when a disallowed custom action is referenced' {
        $sandboxRoot = Join-Path $TestDrive 'guard-disallowed'
        $vipbDir = New-VipbSandbox -Root $sandboxRoot
        foreach ($file in $requiredActionFiles) {
            New-Item -ItemType File -Path (Join-Path $vipbDir $file) -Force | Out-Null
        }

        $vipbCopy = Join-Path $vipbDir 'NI_Icon_editor.vipb'
        (Get-Content -LiteralPath $vipbCopy) `
            -replace 'VIP_Pre-Install Custom Action\.vi','VIP_Pre-Install Custom Action 2021.vi' |
            Set-Content -LiteralPath $vipbCopy

        { & $guardScript -VipbPath $vipbCopy -Workspace $sandboxRoot } | Should -Throw
    }
}
