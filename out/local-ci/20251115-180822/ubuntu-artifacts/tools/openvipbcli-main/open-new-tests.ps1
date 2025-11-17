# open-new-tests.ps1  – create/overwrite test-scaffold files, open each in Notepad

$templates = @{

  'tests/pester/ValidateInsight.Tests.ps1' = @'
Describe 'validate-insight.ps1 basic behaviour' {
    BeforeAll {
        $Validator = Join-Path $PSScriptRoot '..\..\scripts\validate-insight.ps1'
    }

    It 'returns exit code 1 for a missing file' {
        & $Validator -Path 'does-not-exist.json' 2>$null
        $LASTEXITCODE | Should -Be 1
    }
}
'@

  'tests/pester/SynchHook.Tests.ps1' = @'
Describe 'synch-hook.ps1 helper functions' {
    BeforeAll {
        $Hook = Join-Path $PSScriptRoot '..\..\..\.githooks\synch-hook.ps1'
        . $Hook   # dot-source to access functions
    }

    It 'Get-MinVersionFromFile defaults to 0.0.0 when no block present' {
        $tmp = New-TemporaryFile
        '{"foo":"bar"}' | Set-Content $tmp
        Get-MinVersionFromFile $tmp | Should -Be '0.0.0'
    }
}
'@

  'tests/jest/extension.test.ts' = @'
import * as vscode from "vscode";
import { activate } from "../../tooling/vscode-seed-insight/src/extension";

describe("Seed Insight extension", () => {
  it("registers at least one command on activate", () => {
    const ctx = { subscriptions: [] } as unknown as vscode.ExtensionContext;
    activate(ctx);
    expect(ctx.subscriptions.length).toBeGreaterThan(0);
  });
});
'@

  'tooling/vscode-seed-insight/jest.config.js' = @'
module.exports = {
  preset: "ts-jest",
  testEnvironment: "node",
  roots: ["<rootDir>/src", "<rootDir>/../../tests/jest"],
  moduleFileExtensions: ["ts", "js", "json"],
  transform: { "^.+\\.ts$": "ts-jest" }
};
'@
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

foreach ($path in $templates.Keys) {
    $dir = Split-Path $path -Parent
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }

    $templates[$path] | Set-Content -Encoding utf8 -Path $path

    Write-Host "`nOpening Notepad for $path ..."
    Start-Process notepad $path -Wait
}

Write-Host "`nAll files processed.  Next:"

Write-Host "  git add -A"
Write-Host "  git commit -m 'Add Pester + Jest test scaffolds'"
Write-Host "  git push origin main`n"
