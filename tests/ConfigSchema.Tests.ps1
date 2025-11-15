#requires -Version 7.0
$root = $env:WORKSPACE_ROOT
if (-not $root) { $root = '/mnt/data/repo_local' }
if (-not (Test-Path -LiteralPath $root -PathType Container)) {
    $root = (Resolve-Path -LiteralPath '.').Path
}
$repoRoot = (Resolve-Path -LiteralPath $root).Path
$script:root = $root
$script:repoRoot = $repoRoot
$tmp = Join-Path $repoRoot '.tmp-tests'
New-Item -ItemType Directory -Force -Path $tmp | Out-Null

Describe 'Config schema validation' -Tag 'Schema','Linux','CI' {
  It 'validates the example config against the schema' {
    $repoRoot = $script:repoRoot
    $cfg = [System.IO.Path]::Combine($repoRoot,'configs','examples','vi-diff-heuristics.json')
    $schema = [System.IO.Path]::Combine($repoRoot,'configs','schema','vi-diff-heuristics.schema.json')
    Test-Path -LiteralPath $cfg | Should -BeTrue
    Test-Path -LiteralPath $schema | Should -BeTrue
    $content = Get-Content -LiteralPath $cfg -Raw
    { $content | ConvertFrom-Json -ErrorAction Stop | Out-Null } | Should -Not -Throw
    { $content | Test-Json -SchemaFile $schema -ErrorAction Stop | Out-Null } | Should -Not -Throw
  }

  It 'rejects labels longer than 64 chars' {
    $repoRoot = $script:repoRoot
    $schema = [System.IO.Path]::Combine($repoRoot,'configs','schema','vi-diff-heuristics.schema.json')
    $cfg = @{
      label = ('x' * 65)
      inputs = @('samples/project-A')
    } | ConvertTo-Json -Depth 5
    { $cfg | Test-Json -SchemaFile $schema -ErrorAction Stop | Out-Null } | Should -Throw
  }

  It 'rejects path traversal in inputs' {
    $repoRoot = $script:repoRoot
    $schema = [System.IO.Path]::Combine($repoRoot,'configs','schema','vi-diff-heuristics.schema.json')
    $cfg = @{
      label = 'ok'
      inputs = @('../outside')
    } | ConvertTo-Json -Depth 5
    { $cfg | Test-Json -SchemaFile $schema -ErrorAction Stop | Out-Null } | Should -Throw
  }

  It 'rejects dangerous metacharacters in inputs' {
    $repoRoot = $script:repoRoot
    $schema = [System.IO.Path]::Combine($repoRoot,'configs','schema','vi-diff-heuristics.schema.json')
    $cfg = @{
      label = 'ok'
      inputs = @('samples;rm -rf')
    } | ConvertTo-Json -Depth 5
    { $cfg | Test-Json -SchemaFile $schema -ErrorAction Stop | Out-Null } | Should -Throw
  }
}


