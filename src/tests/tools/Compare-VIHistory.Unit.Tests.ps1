[CmdletBinding()]
param()
#Requires -Version 7.0

Describe 'VI Comparison helpers' -Tag 'Unit','Tools','Comparison' {
    BeforeAll {
        $here = $PSScriptRoot
        if (-not $here -and $PSCommandPath) { $here = Split-Path -Parent $PSCommandPath }
        if (-not $here -and $MyInvocation.MyCommand.Path) { $here = Split-Path -Parent $MyInvocation.MyCommand.Path }
        if (-not $here) { throw 'Unable to determine test root for Compare-VIHistory specs.' }
        $script:RepoRoot = (Resolve-Path (Join-Path $here '..\..\..')).Path
        $script:ModulePath = (Resolve-Path (Join-Path $script:RepoRoot 'src/tools/Compare-VIHistory.ps1')).Path
        $source = Get-Content -Raw -Path $script:ModulePath
        $null = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseInput($source, [ref]$null, [ref]$null)
        foreach ($fn in @('Get-ComparisonCategories','Get-ComparisonClassification','Update-TallyFromDetails')) {
            $funcName = $fn
            $funcAst = $ast.Find({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $funcName }, $true)
            if (-not $funcAst) { throw "Unable to locate function '$fn' in Compare-VIHistory.ps1." }
            . ([scriptblock]::Create($funcAst.Extent.Text))
        }
    }

    Context 'Get-ComparisonCategories' {
        It 'extracts normalized categories from highlights' {
            $highlights = @(
                'Block Diagram detected changes',
                'Connector Terminal updated',
                'Window cosmetic update'
            )
            $result = Get-ComparisonCategories -Highlights $highlights -HasDiff $true
            $result | Should -Be @('block-diagram','connector-pane','cosmetic','front-panel')
        }

        It 'adds unspecified category when diff has no highlights' {
            $result = Get-ComparisonCategories -Highlights @() -HasDiff $true
            $result | Should -Be @('unspecified')
        }
    }

    Context 'Get-ComparisonClassification' {
        It 'returns signal when any detail classification is signal' {
            $details = @(
                [pscustomobject]@{ classification = 'noise' },
                [pscustomobject]@{ classification = 'signal' }
            )
            $classification = Get-ComparisonClassification -CategoryDetails $details -HasDiff $true
            $classification | Should -Be 'signal'
        }

        It 'falls back to noise when only neutral entries exist' {
            $details = @([pscustomobject]@{ classification = 'neutral' })
            $classification = Get-ComparisonClassification -CategoryDetails $details -HasDiff $true
            $classification | Should -Be 'noise'
        }
    }

    Context 'Update-TallyFromDetails' {
        It 'increments tally using slug or label when no selector supplied' {
            $details = @(
                [pscustomobject]@{ slug = 'block-diagram' },
                [pscustomobject]@{ label = 'front-panel' },
                [pscustomobject]@{ slug = 'block-diagram' }
            )
            $tally = @{}
            Update-TallyFromDetails -Target $tally -Details $details
            $tally['block-diagram'] | Should -Be 2
            $tally['front-panel'] | Should -Be 1
        }
    }
}
