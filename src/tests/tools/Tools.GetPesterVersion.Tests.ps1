[CmdletBinding()]
param()
#Requires -Version 7.0

function Get-CurrentScriptDirectory {
    if ($PSBoundParameters.ContainsKey('PSScriptRoot') -and $PSScriptRoot) { return $PSScriptRoot }
    if ($PSScriptRoot) { return $PSScriptRoot }
    if ($PSCommandPath) { return (Split-Path -Path $PSCommandPath -Parent) }
    if ($MyInvocation.MyCommand.Path) { return (Split-Path -Path $MyInvocation.MyCommand.Path -Parent) }
    return (Get-Location).Path
}

$script:TestRoot = Get-CurrentScriptDirectory
$script:RepoRoot = (Resolve-Path (Join-Path $script:TestRoot '..\..\..')).Path
$script:ScriptPath = (Resolve-Path (Join-Path $script:RepoRoot 'src/tools/Get-PesterVersion.ps1')).Path
$script:ModuleInfo = New-Module -Name 'ToolsPesterVersion' -ScriptBlock {
    param($path)
    $script:PesterScriptPath = $path
    function Get-PesterVersion {
        [CmdletBinding()]
        param(
            [switch]$EmitEnv,
            [switch]$EmitOutput
        )
        . $script:PesterScriptPath @PSBoundParameters
    }
    . $path
    Export-ModuleMember -Function Get-PesterVersion, Test-ValidLabel, Invoke-WithTimeout
} -ArgumentList $script:ScriptPath
Import-Module -ModuleInfo $script:ModuleInfo -Force
$script:ModuleName = 'ToolsPesterVersion'
$script:PolicyPath = Join-Path (Split-Path $script:ScriptPath -Parent) 'policy' 'tool-versions.json'

Describe 'Get-PesterVersion helpers' -Tag 'Unit','Tools','PesterVersion' {
    Context 'Get-PesterVersion' {
        BeforeEach {
            $script:PolicyOverrideBackup = $env:ICON_EDITOR_PESTER_POLICY
            [System.Environment]::SetEnvironmentVariable('ICON_EDITOR_PESTER_POLICY', $null, 'Process')
        }

        AfterEach {
            [System.Environment]::SetEnvironmentVariable('ICON_EDITOR_PESTER_POLICY', $script:PolicyOverrideBackup, 'Process')
        }

        It 'returns default when policy file is absent' {
            $env:ICON_EDITOR_PESTER_POLICY = Join-Path $TestDrive 'missing-policy.json'
            Get-PesterVersion | Should -Be '5.7.1'
        }

        It 'loads version from policy json when present' {
            $overridePath = Join-Path $TestDrive 'tool-versions.json'
            '{"pester":"6.1.0"}' | Set-Content -Path $overridePath -Encoding utf8
            $env:ICON_EDITOR_PESTER_POLICY = $overridePath
            Get-PesterVersion | Should -Be '6.1.0'
        }
    }

    Context 'GitHub Actions outputs' {
        BeforeEach {
            $script:EnvBackup = @{
                GITHUB_ENV    = $env:GITHUB_ENV
                GITHUB_OUTPUT = $env:GITHUB_OUTPUT
            }
            $env:GITHUB_ENV = Join-Path $TestDrive 'github_env.txt'
            $env:GITHUB_OUTPUT = Join-Path $TestDrive 'github_output.txt'
            $script:PolicyOverrideBackup = $env:ICON_EDITOR_PESTER_POLICY
            [System.Environment]::SetEnvironmentVariable('ICON_EDITOR_PESTER_POLICY', $null, 'Process')
        }

        AfterEach {
            foreach ($pair in $script:EnvBackup.GetEnumerator()) {
                [System.Environment]::SetEnvironmentVariable($pair.Key, $pair.Value, 'Process')
            }
            [System.Environment]::SetEnvironmentVariable('ICON_EDITOR_PESTER_POLICY', $script:PolicyOverrideBackup, 'Process')
        }

        It 'writes resolved version to GITHUB_ENV when EmitEnv is set' {
            Get-PesterVersion -EmitEnv | Out-Null
            Get-Content $env:GITHUB_ENV -Raw | Should -Match 'PESTER_VERSION=5\.7\.1'
        }

        It 'writes resolved version to GITHUB_OUTPUT when EmitOutput is set' {
            Get-PesterVersion -EmitOutput | Out-Null
            Get-Content $env:GITHUB_OUTPUT -Raw | Should -Match 'version=5\.7\.1'
        }
    }

    Context 'Test-ValidLabel' {
        It 'passes for valid labels' {
            { Test-ValidLabel -Label 'Alpha-123' -Confirm:$false } | Should -Not -Throw
        }

        It 'throws for invalid labels' {
            { Test-ValidLabel -Label 'invalid label!' -Confirm:$false } | Should -Throw '*Invalid label*'
        }
    }

    Context 'Invoke-WithTimeout' {
        It 'returns job output when job completes in time' {
            Invoke-WithTimeout -ScriptBlock { 'done' } -TimeoutSec 10 | Should -Be 'done'
        }

        It 'stops job and throws when timeout elapses' {
            { Invoke-WithTimeout -ScriptBlock { Start-Sleep -Seconds 5 } -TimeoutSec 1 } | Should -Throw '*timed out*'
        }
    }
}
