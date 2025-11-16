$root = $env:WORKSPACE_ROOT
if (-not $root) { $root = '/mnt/data/repo_local' }
if (-not (Test-Path -LiteralPath $root -PathType Container)) {
    $scriptDir = Split-Path -Parent $PSCommandPath
    $probe = $scriptDir
    while ($probe -and (Split-Path -Leaf $probe) -ne 'tests') {
        $next = Split-Path -Parent $probe
        if (-not $next -or $next -eq $probe) { break }
        $probe = $next
    }
    if ($probe -and (Split-Path -Leaf $probe) -eq 'tests') {
        $root = Split-Path -Parent $probe
    }
    else {
        $root = $scriptDir
    }
}
$repoRoot = (Resolve-Path -LiteralPath $root).Path
$tmp = Join-Path $repoRoot '.tmp-tests'
New-Item -ItemType Directory -Force -Path $tmp | Out-Null

$helperPath = Join-Path $repoRoot 'tests/_helpers/Import-ScriptFunctions.ps1'
if (-not (Test-Path -LiteralPath $helperPath -PathType Leaf)) {
    Describe 'IconEditorDevMode x-cli integration' {
        It 'skips when Import-ScriptFunctions is missing' -Skip {
            # Helper script not present in this snapshot.
        }
    }
    return
}
. $helperPath

$devModeModulePath = Join-Path $repoRoot 'src/tools/icon-editor/IconEditorDevMode.psm1'
if (-not (Test-Path -LiteralPath $devModeModulePath -PathType Leaf)) {
    Describe 'IconEditorDevMode x-cli integration' {
        It 'skips when IconEditorDevMode.psm1 is absent' -Skip {
            # Module not present in this snapshot.
        }
    }
    return
}

$null = Import-ScriptFunctions -ScriptPath $devModeModulePath -FunctionNames @(
    'Invoke-IconEditorDevModeScriptWithXCli',
    'Write-DevModeScriptLog'
)

Describe 'Invoke-IconEditorDevModeScriptWithXCli' {
    BeforeAll {
        function script:New-DotnetStub {
            $stubPath = Join-Path $TestDrive ("dotnet-stub-{0}.ps1" -f ([guid]::NewGuid().ToString('n')))
            $stubBody = @'
param()
$log = $env:DOTNET_STUB_LOG
if (-not $log) { throw 'DOTNET_STUB_LOG not set' }
($args | ConvertTo-Json -Compress) | Set-Content -LiteralPath $log -Encoding utf8
$rc = 0
if ($env:DOTNET_STUB_RC) {
    $rc = [int]$env:DOTNET_STUB_RC
}
exit $rc
'@
            Set-Content -LiteralPath $stubPath -Value $stubBody -Encoding utf8
            return $stubPath
        }

        function script:New-XCliReadyRepo {
            $repo = Join-Path $TestDrive ([guid]::NewGuid().ToString('n'))
            New-Item -ItemType Directory -Path $repo -Force | Out-Null

            $projectDir = Join-Path $repo 'tools/x-cli-develop/src/XCli'
            New-Item -ItemType Directory -Path $projectDir -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $projectDir 'XCli.csproj') -Value '<Project />' -Encoding utf8

            $scriptPath = Join-Path $repo 'tools/icon-editor/Enable-DevMode.ps1'
            New-Item -ItemType Directory -Path (Split-Path -Parent $scriptPath) -Force | Out-Null
            Set-Content -LiteralPath $scriptPath -Value 'param()' -Encoding utf8

            $iconRoot = Join-Path $repo 'vendor/labview-icon-editor'
            New-Item -ItemType Directory -Path $iconRoot -Force | Out-Null

            return [pscustomobject]@{
                RepoRoot   = (Convert-Path $repo)
                ScriptPath = (Convert-Path $scriptPath)
                IconRoot   = (Convert-Path $iconRoot)
            }
        }
    }

    AfterEach {
        Remove-Item Env:ICONEDITORLAB_RUN_ID -ErrorAction SilentlyContinue
        Remove-Item Env:ICONEDITORLAB_SIM_SCENARIO -ErrorAction SilentlyContinue
        Remove-Item Env:XCLI_DEV_MODE_ROOT -ErrorAction SilentlyContinue
        Remove-Item Env:DOTNET_STUB_LOG -ErrorAction SilentlyContinue
        Remove-Item Env:DOTNET_STUB_RC -ErrorAction SilentlyContinue
    }

    Context 'Pre-flight guard rails' {
        It 'throws a clear error when tools/x-cli-develop is missing' {
            $repo = Join-Path $TestDrive ([guid]::NewGuid().ToString('n'))
            New-Item -ItemType Directory -Path $repo -Force | Out-Null
            $scriptPath = Join-Path $repo 'tools/icon-editor/Enable-DevMode.ps1'
            New-Item -ItemType Directory -Path (Split-Path -Parent $scriptPath) -Force | Out-Null
            Set-Content -LiteralPath $scriptPath -Value 'param()' -Encoding utf8
            $iconRoot = Join-Path $repo 'vendor/labview-icon-editor'
            New-Item -ItemType Directory -Path $iconRoot -Force | Out-Null

            $action = {
                Invoke-IconEditorDevModeScriptWithXCli -ScriptPath $scriptPath -RepoRoot $repo -IconEditorRoot $iconRoot -StageLabel 'enable-dev-mode'
            }
            $action | Should -Throw -ExpectedMessage '*XCli project not found*'
        }
    }

    Context 'x-cli command construction' {
        It 'passes lvaddon arguments, metadata, and clears temp env vars when dotnet succeeds' {
            $repoInfo = New-XCliReadyRepo
            $dotnetLog = Join-Path $TestDrive 'dotnet-success.log'
            $env:DOTNET_STUB_LOG = $dotnetLog
            $env:DOTNET_STUB_RC = '0'
            $env:ICONEDITORLAB_RUN_ID = 'run-123'
            $env:ICONEDITORLAB_SIM_SCENARIO = 'timeout'

            $dotnetStub = New-DotnetStub
            Mock -CommandName Get-Command -ParameterFilter { $Name -eq 'dotnet' } -MockWith {
                [pscustomobject]@{ Source = $dotnetStub }
            }

            $argumentList = @(
                '-MinimumSupportedLVVersion','2023',
                '-SupportedBitness','64-bit',
                '-IconEditorRoot', $repoInfo.IconRoot
            )

            Invoke-IconEditorDevModeScriptWithXCli `
                -ScriptPath $repoInfo.ScriptPath `
                -ArgumentList $argumentList `
                -RepoRoot $repoInfo.RepoRoot `
                -IconEditorRoot $repoInfo.IconRoot `
                -StageLabel 'enable-sim'

            Test-Path Env:XCLI_DEV_MODE_ROOT | Should -BeFalse
            Test-Path -LiteralPath $dotnetLog | Should -BeTrue

            $argsFromStub = Get-Content -LiteralPath $dotnetLog -Raw | ConvertFrom-Json
            $argsFromStub[0] | Should -Be 'run'
            $argsFromStub[1] | Should -Be '--project'
            ($argsFromStub[2] -replace '\\','/') | Should -Match 'tools/x-cli-develop/.+/XCli.csproj$'

            $payloadStart = [Array]::IndexOf($argsFromStub, '--')
            $payload = $argsFromStub[($payloadStart + 1)..($argsFromStub.Length - 1)]

            $payload | Should -Contain 'labview-devmode-enable'
            $lvRootIndex = [Array]::IndexOf($payload, '--lvaddon-root')
            $payload[$lvRootIndex + 1] | Should -Be $repoInfo.IconRoot

            $lvVersionIndex = [Array]::IndexOf($payload, '--lv-version')
            $payload[$lvVersionIndex + 1] | Should -Be '2023'

            $bitnessIndex = [Array]::IndexOf($payload, '--bitness')
            $payload[$bitnessIndex + 1] | Should -Be '64-bit'

            $argsJsonIndex = [Array]::IndexOf($payload, '--args-json')
            $decodedArgs = @((ConvertFrom-Json -InputObject $payload[$argsJsonIndex + 1]))
            $decodedArgs | Should -BeExactly $argumentList

            $scenarioIndex = [Array]::IndexOf($payload, '--scenario')
            $payload[$scenarioIndex + 1] | Should -Be 'timeout'

            $operationIndex = [Array]::IndexOf($payload, '--operation')
            $payload[$operationIndex + 1] | Should -Be 'enable-sim'

            $runIdIndex = [Array]::IndexOf($payload, '--run-id')
            $payload[$runIdIndex + 1] | Should -Be 'run-123'

            $logDir = Join-Path $repoInfo.RepoRoot 'tests/results/_agent/icon-editor/dev-mode-script'
            (Get-ChildItem -LiteralPath $logDir -Filter '*.log' | Measure-Object).Count | Should -BeGreaterThan 0
        }

        It 'surfaces non-zero dotnet exits and restores prior XCLI_DEV_MODE_ROOT' {
            $repoInfo = New-XCliReadyRepo
            $dotnetLog = Join-Path $TestDrive 'dotnet-fail.log'
            $env:DOTNET_STUB_LOG = $dotnetLog
            $env:DOTNET_STUB_RC = '9'
            $env:ICONEDITORLAB_RUN_ID = 'run-err'
            $env:XCLI_DEV_MODE_ROOT = 'C:\preexisting-root'

            $dotnetStub = New-DotnetStub
            Mock -CommandName Get-Command -ParameterFilter { $Name -eq 'dotnet' } -MockWith {
                [pscustomobject]@{ Source = $dotnetStub }
            }

            $action = {
                Invoke-IconEditorDevModeScriptWithXCli `
                    -ScriptPath $repoInfo.ScriptPath `
                    -RepoRoot $repoInfo.RepoRoot `
                    -IconEditorRoot $repoInfo.IconRoot `
                    -StageLabel 'disable-sim'
            }

            $action | Should -Throw -ExpectedMessage '*Dev-mode simulation via x-cli*9*'
            $env:XCLI_DEV_MODE_ROOT | Should -Be 'C:\preexisting-root'
            Test-Path -LiteralPath $dotnetLog | Should -BeTrue
            $logDir = Join-Path $repoInfo.RepoRoot 'tests/results/_agent/icon-editor/dev-mode-script'
            (Get-ChildItem -LiteralPath $logDir -Filter '*.log' | Measure-Object).Count | Should -BeGreaterThan 0
        }
    }
}
