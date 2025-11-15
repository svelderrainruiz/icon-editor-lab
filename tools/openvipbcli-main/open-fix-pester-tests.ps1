# open-fix-pester-tests.ps1
# Fixes failing Pester tests by correcting relative paths and exit‐code capture.

$templates = @{
  'tests/pester/SynchHook.Tests.ps1' = @'
Describe "synch-hook.ps1 helper functions" {
    BeforeAll {
        $Hook = Join-Path $PSScriptRoot '..\..\.githooks\synch-hook.ps1'
        . $Hook   # dot-source to access functions
    }

    It "Get-MinVersionFromFile defaults to 0.0.0 when no block present" {
        $tmp = New-TemporaryFile
        '{"foo":"bar"}' | Set-Content $tmp
        Get-MinVersionFromFile $tmp | Should -Be '0.0.0'
    }
}
'@

  'tests/pester/ValidateInsight.Tests.ps1' = @'
Describe "validate-insight.ps1 basic behaviour" {
    BeforeAll {
        $Validator = Join-Path $PSScriptRoot '..\..\scripts\validate-insight.ps1'
    }

    It "returns exit code 1 for a missing file" {
        & pwsh -NoProfile -File $Validator -Path 'does-not-exist.json' 2>$null
        $LASTEXITCODE | Should -Be 1
    }
}
'@
}

foreach ($path in $templates.Keys) {
    $dir = Split-Path $path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $templates[$path] | Set-Content -Encoding utf8 -Path $path
    Write-Host "Updated $path"
}

Write-Host "\nNext:"
Write-Host "  git add tests/pester/*.ps1"
Write-Host "  git commit -m 'Fix Pester tests: correct paths & exit‐code capture'"
Write-Host "  git push origin main\n"
