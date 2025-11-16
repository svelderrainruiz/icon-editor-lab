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
. (Join-Path $root 'tests/_helpers/Import-ScriptFunctions.ps1')
$scriptPath = Join-Path $repoRoot 'local-ci/windows/scripts/Invoke-ViCompareLabVIEWCli.ps1'
$scriptExists = Test-Path -LiteralPath $scriptPath -PathType Leaf
if ($scriptExists) {
    Import-ScriptFunctions -Path $scriptPath -FunctionNames @('Resolve-ExistingPath','Read-ViDiffPairs','Write-StubArtifacts','Get-PropertyValue') | Out-Null
}

Describe 'Invoke-ViCompareLabVIEWCli.ps1' {
    if (-not $scriptExists) {
        It 'skips when Invoke-ViCompareLabVIEWCli.ps1 is absent' -Skip {
            # File not present in this repo snapshot.
        }
        return
    }
    Context 'Resolve-ExistingPath' {
        It 'resolves relative files using the provided probe roots' {
            $probeRoot = Join-Path $TestDrive 'probes'
            New-Item -ItemType Directory -Path $probeRoot | Out-Null
            $target = Join-Path $probeRoot 'Nested/Example.vi'
            New-Item -ItemType Directory -Path (Split-Path -Parent $target) | Out-Null
            Set-Content -LiteralPath $target -Value 'stub'

            $resolved = Resolve-ExistingPath -PathValue 'Nested/Example.vi' -Roots @($probeRoot)
            $resolved | Should -Be (Convert-Path $target)
        }

        It 'returns null when the candidate cannot be resolved' {
            Resolve-ExistingPath -PathValue 'missing.vi' -Roots @($TestDrive) | Should -Be $null
        }

        It 'normalizes and resolves existing absolute paths verbatim' {
            $absolutePath = Join-Path $TestDrive 'Absolute/Test.vi'
            New-Item -ItemType Directory -Path (Split-Path -Parent $absolutePath) -Force | Out-Null
            Set-Content -LiteralPath $absolutePath -Value 'abs'

            $resolved = Resolve-ExistingPath -PathValue "  $absolutePath  " -Roots @()
            $resolved | Should -Be (Convert-Path $absolutePath)
        }
    }

    Context 'Get-PropertyValue' {
        It 'returns the property value when present' {
            $obj = [pscustomobject]@{ Name = 'delta'; Version = '1.0.0' }

            Get-PropertyValue -Object $obj -Name 'Version' | Should -Be '1.0.0'
        }

        It 'returns null for missing names or null objects' {
            $obj = [pscustomobject]@{ Name = 'delta' }

            Get-PropertyValue -Object $obj -Name 'Unknown' | Should -Be $null
            Get-PropertyValue -Object $null -Name 'Name' | Should -Be $null
        }
    }

    Context 'Read-ViDiffPairs' {
        It 'parses request files with the requests schema' {
            $requestPath = Join-Path $TestDrive 'requests.json'
            @"
{
  "requests": [
    { "pairId": "ui.vi", "baseline": { "path": "A/ui.vi" }, "candidate": { "path": "B/ui.vi" } }
  ]
}
"@ | Set-Content -LiteralPath $requestPath -Encoding UTF8

            $pairs = Read-ViDiffPairs -RequestsPath $requestPath
            $pairs.Count | Should -Be 1
            $pairs[0].Baseline | Should -Be 'A/ui.vi'
            $pairs[0].Candidate | Should -Be 'B/ui.vi'
        }

        It 'supports the legacy pairs schema layout' {
            $requestPath = Join-Path $TestDrive 'pairs.json'
@"
{
  "pairs": [
    {
      "pair_id": "ui/control.vi",
      "baseline": { "path": "old/control.vi" },
      "candidate": { "path": "new/control.vi" },
      "labels": ["ui", "control"]
    }
  ]
}
"@ | Set-Content -LiteralPath $requestPath -Encoding UTF8

            $pairs = Read-ViDiffPairs -RequestsPath $requestPath
            $pairs.Count | Should -Be 1
            $pairs[0].Id | Should -Be 'ui/control.vi'
            $pairs[0].Baseline | Should -Be 'old/control.vi'
            $pairs[0].Candidate | Should -Be 'new/control.vi'
            $pairs[0].Label | Should -Match 'ui'
        }

        It 'throws when the JSON payload lacks supported nodes' {
            $requestPath = Join-Path $TestDrive 'unknown.json'
            '{"foo":[1,2,3]}' | Set-Content -LiteralPath $requestPath -Encoding UTF8
            try {
                Read-ViDiffPairs -RequestsPath $requestPath
                throw 'Expected Read-ViDiffPairs to reject unknown schemas.'
            } catch {
                $_.Exception.Message | Should -Match 'Unrecognized vi-diff request schema'
            }
        }

        It 'throws when the JSON is malformed' {
            $requestPath = Join-Path $TestDrive 'bad.json'
            '{' | Set-Content -LiteralPath $requestPath -Encoding UTF8
            { Read-ViDiffPairs -RequestsPath $requestPath } | Should -Throw
        }
    }

    Context 'Write-StubArtifacts' {
        It 'writes capture, session, and report files for a dry-run pair' {
            $pairRoot = Join-Path $TestDrive 'capture'
            New-Item -ItemType Directory -Path $pairRoot | Out-Null
            Write-StubArtifacts -PairRoot $pairRoot -Reason 'dry-run sample' -Status 'dry-run'

            Test-Path -LiteralPath (Join-Path $pairRoot 'lvcompare-capture.json') | Should -BeTrue
            Test-Path -LiteralPath (Join-Path $pairRoot 'session-index.json') | Should -BeTrue
            Test-Path -LiteralPath (Join-Path $pairRoot 'compare-report.html') | Should -BeTrue

            (Get-Content -LiteralPath (Join-Path $pairRoot 'lvcompare-capture.json') -Raw) | Should -Match 'dry-run sample'
        }

        It 'HTML-encodes the reason text inside the stub report' {
            $pairRoot = Join-Path $TestDrive 'html-capture'
            New-Item -ItemType Directory -Path $pairRoot | Out-Null
            Write-StubArtifacts -PairRoot $pairRoot -Reason '<script>alert(1)</script>' -Status 'error'

            $html = Get-Content -LiteralPath (Join-Path $pairRoot 'compare-report.html') -Raw
            $html | Should -Match '&lt;script&gt;alert\(1\)&lt;/script&gt;'
            (Get-Content -LiteralPath (Join-Path $pairRoot 'lvcompare-capture.json') -Raw) | Should -Match 'error'
        }
    }
}


