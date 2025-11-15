[CmdletBinding()]
param()
#Requires -Version 7.0

function Script:New-TestAddonRepo {
    param(
        [switch]$WithOrigin,
        [string]$OriginUrl = 'https://github.com/example/lv-addon.git',
        [switch]$WithLvproj
    )

    $path = Join-Path $TestDrive ([guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Path $path | Out-Null
    git -C $path init | Out-Null
    if ($WithOrigin) {
        git -C $path remote add origin $OriginUrl | Out-Null
    }
    if ($WithLvproj) {
        Set-Content -LiteralPath (Join-Path $path 'sample.lvproj') -Value '<Project></Project>' -Encoding utf8
    }
    return (Resolve-Path -LiteralPath $path -ErrorAction Stop).ProviderPath
}

Describe 'VendorTools LV add-on lab detection' -Tag 'Unit','Tools','VendorTools' {
    BeforeAll {
        $repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..' '..' '..') -ErrorAction Stop).ProviderPath
        $script:modulePath = (Resolve-Path -LiteralPath (Join-Path $repoRoot 'src/tools/VendorTools.psm1') -ErrorAction Stop).ProviderPath
        if (Get-Module -Name VendorTools -ErrorAction SilentlyContinue) {
            Remove-Module VendorTools -Force -ErrorAction SilentlyContinue
        }
        Import-Module -Name $script:modulePath -Force -ErrorAction Stop
    }

    AfterAll {
        if (Get-Module -Name VendorTools -ErrorAction SilentlyContinue) {
            Remove-Module VendorTools -Force -ErrorAction SilentlyContinue
        }
    }


    Context 'Test-LVAddonLabPath' {
        It 'identifies git repo with origin and LV project as LV add-on lab' {
            $repo = New-TestAddonRepo -WithOrigin -WithLvproj
            $analysis = Test-LVAddonLabPath -Path $repo
            $analysis.IsDirectory | Should -BeTrue
            $analysis.IsGitRepo  | Should -BeTrue
            $analysis.HasOrigin  | Should -BeTrue
            $analysis.IsAllowedHost | Should -BeTrue
            $analysis.IsLVAddonLab | Should -BeTrue
        }

        It 'flags missing origin' {
            $repo = New-TestAddonRepo
            $analysis = Test-LVAddonLabPath -Path $repo
            $analysis.IsGitRepo | Should -BeTrue
            $analysis.HasOrigin | Should -BeFalse
        }

        It 'detects non-GitHub origin host' {
            $repo = New-TestAddonRepo -WithOrigin -OriginUrl 'https://gitlab.example/lv-addon.git' -WithLvproj
            $analysis = Test-LVAddonLabPath -Path $repo
            $analysis.IsAllowedHost | Should -BeFalse
            $analysis.IsLVAddonLab | Should -BeTrue
        }
    }

    Context 'Assert-LVAddonLabPath' {
        It 'throws for non git directories' {
            $path = Join-Path $TestDrive 'not-a-repo'
            New-Item -ItemType Directory -Path $path | Out-Null
            {
                Assert-LVAddonLabPath -Path $path -Strict
            } | Should -Throw "*not a git repository*"
        }

        It 'throws when origin host is not allowed in strict mode' {
            $repo = New-TestAddonRepo -WithOrigin -OriginUrl 'https://gitlab.example/lv-addon.git' -WithLvproj
            {
                Assert-LVAddonLabPath -Path $repo -Strict -AllowedHosts @('github.com')
            } | Should -Throw "*not on an allowed GitHub host*"
        }

        It 'honors additional allowed hosts' {
            $repo = New-TestAddonRepo -WithOrigin -OriginUrl 'https://github.mycorp.com/lv-addon.git' -WithLvproj
            {
                Assert-LVAddonLabPath -Path $repo -Strict -AllowedHosts @('github.com','github.mycorp.com')
            } | Should -Not -Throw
        }

        It 'throws when LV project is missing in strict mode' {
            $repo = New-TestAddonRepo -WithOrigin
            {
                Assert-LVAddonLabPath -Path $repo -Strict
            } | Should -Throw "*does not appear to contain a LabVIEW add-on project*"
        }
    }
}
