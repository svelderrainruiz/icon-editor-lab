#requires -Version 7.0
Describe 'Config schema validation' -Tag 'Schema','Linux','CI' {
  It 'validates the example config against the schema' {
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $cfg = Join-Path $repoRoot 'configs' 'examples' 'vi-diff-heuristics.json'
    $schema = Join-Path $repoRoot 'configs' 'schema' 'vi-diff-heuristics.schema.json'
    Test-Path -LiteralPath $cfg | Should -BeTrue
    Test-Path -LiteralPath $schema | Should -BeTrue
    $content = Get-Content -LiteralPath $cfg -Raw
    { $content | ConvertFrom-Json -ErrorAction Stop | Out-Null } | Should -Not -Throw
    { $content | Test-Json -SchemaFile $schema -ErrorAction Stop | Out-Null } | Should -Not -Throw
  }
}

  It 'rejects labels longer than 64 chars' {
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $schema = Join-Path $repoRoot 'configs' 'schema' 'vi-diff-heuristics.schema.json'
    $cfg = @{
      label = ('x' * 65)
      inputs = @('samples/project-A')
    } | ConvertTo-Json -Depth 5
    { $cfg | Test-Json -SchemaFile $schema -ErrorAction Stop | Out-Null } | Should -Throw
  }

  It 'rejects path traversal in inputs' {
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $schema = Join-Path $repoRoot 'configs' 'schema' 'vi-diff-heuristics.schema.json'
    $cfg = @{
      label = 'ok'
      inputs = @('../outside')
    } | ConvertTo-Json -Depth 5
    { $cfg | Test-Json -SchemaFile $schema -ErrorAction Stop | Out-Null } | Should -Throw
  }

  It 'rejects dangerous metacharacters in inputs' {
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $schema = Join-Path $repoRoot 'configs' 'schema' 'vi-diff-heuristics.schema.json'
    $cfg = @{
      label = 'ok'
      inputs = @('samples;rm -rf')
    } | ConvertTo-Json -Depth 5
    { $cfg | Test-Json -SchemaFile $schema -ErrorAction Stop | Out-Null } | Should -Throw
  }
