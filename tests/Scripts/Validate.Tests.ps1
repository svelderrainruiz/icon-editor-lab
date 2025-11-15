$root = $env:WORKSPACE_ROOT
if (-not $root) { $root = '/mnt/data/repo_local' }
if (-not (Test-Path -LiteralPath $root -PathType Container)) {
    $root = (Resolve-Path -LiteralPath '.').Path
}
$repoRoot = (Resolve-Path -LiteralPath $root).Path
$tmp = Join-Path $repoRoot '.tmp-tests'
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$validateModulePath = Join-Path $repoRoot 'tools/Validate-Paths.psm1'
$validateConfigPath = Join-Path $repoRoot 'tools/Validate-Config.ps1'

function script:Invoke-ValidationScript {
    param(
        [Parameter(Mandatory)][string]$ScriptPath,
        [hashtable]$Parameters,
        [string[]]$Switches
    )

    Import-Module Microsoft.PowerShell.Management -ErrorAction SilentlyContinue | Out-Null
    Import-Module Microsoft.PowerShell.Utility -ErrorAction SilentlyContinue | Out-Null

    $splat = [ordered]@{}

    if ($Parameters) {
        foreach ($key in $Parameters.Keys) {
            $splat[$key] = $Parameters[$key]
        }
    }

    if ($Switches) {
        foreach ($switchName in $Switches) {
            $splat[$switchName] = $true
        }
    }

    $stdOut = @()
    $stdErr = @()
    $exitCode = 0
    $originalErrorAction = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Stop'
        $stdOut = & $ScriptPath @splat
    } catch {
        $exitCode = 1
        $stdErr = @((($_ | Out-String).Trim()))
    } finally {
        $ErrorActionPreference = $originalErrorAction
    }

    return [pscustomobject]@{
        ExitCode = $exitCode
        StdOut   = @($stdOut | ForEach-Object { $_.ToString() })
        StdErr   = @($stdErr | Where-Object { $_ })
    }
}

Describe 'Validate-Paths.psm1' {
    $modulePath = $validateModulePath

    if (-not (Test-Path -LiteralPath $modulePath)) {
        It 'skips when Validate-Paths.psm1 is absent' -Skip {
            # Module not present.
        }
        return
    }

    Import-Module $modulePath -Force

    Context 'Test-PathSafe' {
        It 'accepts an existing absolute path' {
            $filePath = Join-Path $TestDrive 'example.txt'
            'content' | Set-Content -LiteralPath $filePath
            InModuleScope Validate-Paths {
                Test-PathSafe -Path $args[0] -RequireAbsolute | Should -BeTrue
            } -ArgumentList $filePath
        }

        It 'rejects unsafe traversal paths' {
            InModuleScope Validate-Paths {
                Test-PathSafe -Path '../etc/passwd' | Should -BeFalse
            }
        }
    }

    Context 'Validate-PathSafe' {
        It 'returns the resolved path when valid' {
            $dirPath = Join-Path $TestDrive 'safe-dir'
            New-Item -ItemType Directory -Path $dirPath | Out-Null
            $resolved = InModuleScope Validate-Paths {
                Validate-PathSafe -Path $args[0]
            } -ArgumentList $dirPath
            $resolved | Should -Be ((Resolve-Path -LiteralPath $dirPath).Path)
        }

        It 'throws when the path violates validation rules' {
            { InModuleScope Validate-Paths { Validate-PathSafe -Path '..\bad' } } | Should -Throw
        }
    }
}

Describe 'Validate-Config.ps1' {
    $scriptPath = $validateConfigPath

    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
        It 'skips when Validate-Config.ps1 is absent' -Skip {
            # Script not present.
        }
        return
    }

    $resolvedValidateConfigPath = $null
    BeforeAll {
        $localRoot = $env:WORKSPACE_ROOT
        if (-not $localRoot) { $localRoot = '/mnt/data/repo_local' }
        $localRepo = (Resolve-Path -LiteralPath $localRoot).Path
        $resolvedValidateConfigPath = (Convert-Path (Join-Path $localRepo 'tools/Validate-Config.ps1'))
    }

    Context 'Invocation' {
        It 'prints a success message for valid JSON input' {
            $configPath = Join-Path $TestDrive 'config.json'
            '{"name":"icon"}' | Set-Content -LiteralPath $configPath -Encoding UTF8
            $schemaPath = Join-Path $TestDrive 'schema.json'
            '{"type":"object"}' | Set-Content -LiteralPath $schemaPath -Encoding UTF8
            $configFs = Convert-Path $configPath
            $schemaFs = Convert-Path $schemaPath

            $result = Invoke-ValidationScript -ScriptPath $resolvedValidateConfigPath -Parameters (@{ ConfigPath = $configFs; SchemaPath = $schemaFs })
            $result.ExitCode | Should -Be 0
            $result.StdOut[-1] | Should -Match ([Regex]::Escape($configFs))
        }

        It 'throws when the JSON content is invalid' {
            $configPath = Join-Path $TestDrive 'invalid.json'
            'not-json' | Set-Content -LiteralPath $configPath -Encoding UTF8
            $schemaPath = Join-Path $TestDrive 'schema.json'
            '{"type":"object"}' | Set-Content -LiteralPath $schemaPath -Encoding UTF8
            $configFs = Convert-Path $configPath
            $schemaFs = Convert-Path $schemaPath

            $result = Invoke-ValidationScript -ScriptPath $resolvedValidateConfigPath -Parameters (@{ ConfigPath = $configFs; SchemaPath = $schemaFs })
            $result.ExitCode | Should -Not -Be 0
            ($result.StdErr -join [Environment]::NewLine) | Should -Match 'Conversion from JSON failed'
        }

        It 'succeeds gracefully when the referenced schema file is missing' {
            $configPath = Join-Path $TestDrive 'config-no-schema.json'
            '{"name":"icon","version":"1.0.0"}' | Set-Content -LiteralPath $configPath -Encoding UTF8
            $configFs = Convert-Path $configPath
            $missingSchema = Join-Path $TestDrive 'schema-missing.json'
            if (Test-Path -LiteralPath $missingSchema) {
                Remove-Item -LiteralPath $missingSchema -Force
            }

            $result = Invoke-ValidationScript -ScriptPath $resolvedValidateConfigPath -Parameters (@{ ConfigPath = $configFs; SchemaPath = $missingSchema })
            $result.ExitCode | Should -Be 0
            $result.StdOut[-1] | Should -Match ([Regex]::Escape($configFs))
        }

        It 'returns a failure when the schema file is malformed JSON' {
            $configPath = Join-Path $TestDrive 'config-valid.json'
            '{"name":"icon"}' | Set-Content -LiteralPath $configPath -Encoding UTF8
            $schemaPath = Join-Path $TestDrive 'schema-malformed.json'
            'not-json' | Set-Content -LiteralPath $schemaPath -Encoding UTF8
            $configFs = Convert-Path $configPath
            $schemaFs = Convert-Path $schemaPath

            $result = Invoke-ValidationScript -ScriptPath $resolvedValidateConfigPath -Parameters (@{ ConfigPath = $configFs; SchemaPath = $schemaFs })
            $result.ExitCode | Should -Not -Be 0
            ($result.StdErr -join [Environment]::NewLine) | Should -Match 'Test-Json'
        }
    }
}


