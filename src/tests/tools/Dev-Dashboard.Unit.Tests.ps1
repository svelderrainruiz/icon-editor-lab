[CmdletBinding()]
param()
#Requires -Version 7.0

Describe 'Dev Dashboard helpers' -Tag 'Unit','Tools','DevDashboard' {
    BeforeAll {
        $here = $PSScriptRoot
        if (-not $here -and $PSCommandPath) { $here = Split-Path -Parent $PSCommandPath }
        if (-not $here -and $MyInvocation.MyCommand.Path) { $here = Split-Path -Parent $MyInvocation.MyCommand.Path }
        if (-not $here) { throw 'Unable to determine test root for Dev-Dashboard specs.' }
        $script:RepoRoot = (Resolve-Path (Join-Path $here '..\..\..')).Path
        $script:ModulePath = (Resolve-Path (Join-Path $script:RepoRoot 'src/tools/Dev-Dashboard.psm1')).Path
        $script:ModuleInfo = Import-Module -Name $script:ModulePath -Force -PassThru
        $script:ModuleName = $script:ModuleInfo.Name
    }

    AfterAll {
        if ($script:ModuleName) {
            Remove-Module -Name $script:ModuleName -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'Resolve-PathSafe' {
        It 'returns absolute path when input exists' {
            $file = Join-Path $TestDrive 'exists.txt'
            'hello' | Set-Content -Path $file -Encoding utf8
            $expected = (Resolve-Path -Path $file).Path
            $result = Resolve-PathSafe -Path $file
            $result | Should -Be $expected
        }

        It 'returns null when file is missing' {
            $missing = Join-Path $TestDrive 'missing.txt'
            $result = Resolve-PathSafe -Path $missing
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Read-JsonFile' {
        It 'loads json content and reports success' {
            $jsonPath = Join-Path $TestDrive 'config.json'
            '{"foo":"bar","answer":42}' | Set-Content -LiteralPath $jsonPath -Encoding utf8
            $info = Read-JsonFile -Path $jsonPath
            $info.Exists | Should -BeTrue
            $info.Data.foo | Should -Be 'bar'
            $info.Error | Should -BeNullOrEmpty
        }

        It 'captures parse errors when file contains invalid json' {
            $badPath = Join-Path $TestDrive 'broken.json'
            '{not json}' | Set-Content -LiteralPath $badPath -Encoding utf8
            $info = Read-JsonFile -Path $badPath
            $info.Exists | Should -BeTrue
            $info.Data | Should -BeNullOrEmpty
            $info.Error | Should -Not -BeNullOrEmpty
        }

        It 'reports missing files without throwing' {
            $missing = Join-Path $TestDrive 'nope.json'
            $info = Read-JsonFile -Path $missing
            $info.Exists | Should -BeFalse
            $info.Path | Should -BeNullOrEmpty
        }
    }

    Context 'Read-FileLines' {
        It 'returns line content when file exists' {
            $linesPath = Join-Path $TestDrive 'lines.txt'
            @('one','two','three') | Set-Content -LiteralPath $linesPath -Encoding utf8
            $info = Read-FileLines -Path $linesPath
            $info.Exists | Should -BeTrue
            $info.Lines | Should -Contain 'two'
        }

        It 'gracefully handles unreadable files' {
            $file = Join-Path $TestDrive 'locked.txt'
            'line' | Set-Content -LiteralPath $file -Encoding utf8
            Mock -CommandName Get-Content -ModuleName $script:ModuleName -MockWith { throw 'IO failure' }
            $info = Read-FileLines -Path $file
            $info.Exists | Should -BeFalse
            $info.Error | Should -Match 'IO failure'
        }
    }

    Context 'Read-NdjsonFile' {
        It 'collects objects separated by blank lines' {
            $ndjson = Join-Path $TestDrive 'items.ndjson'
            @(
                '{"schema":"v1"}',
                '',
                '{"schema":"v1","value":2}',
                ''
            ) | Set-Content -LiteralPath $ndjson -Encoding utf8
            $info = Read-NdjsonFile -Path $ndjson
            $info.Exists | Should -BeTrue
            $info.Items | Should -HaveCount 2
            $info.Items[1].value | Should -Be 2
        }
    }
}
