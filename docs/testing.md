Testing signed workflows in a fork (no prod secrets)

When to use
- Use this when you want to run the codesign-dev/codesign-prod jobs in your fork without access to the org’s production code-signing secrets. This keeps the workflow identical while using a throwaway certificate.

Generate a test certificate (Windows + PowerShell 7)

```
# From the repo root:
pwsh -File tools/Generate-TestCodeSignCert.ps1 `
  -OutDir .\out\test-codesign `
  -EmitJson -EmitEnv
```

This creates a self‑signed code‑signing cert (valid ~14 days), exports a PFX, and writes:
- `out/test-codesign/WIN_CODESIGN_PFX_B64.txt`
- `out/test-codesign/WIN_CODESIGN_PFX_PASSWORD.txt`
- (optional) `out/test-codesign/secrets.json`, `secrets.env`

Add environment secrets in your fork

Make sure your fork has the environments `codesign-dev` and (optionally) `codesign-prod`.
You can create them in the GitHub UI, or via `gh`:

```
gh api repos/:owner/:repo/environments -f name=codesign-dev
gh api repos/:owner/:repo/environments -f name=codesign-prod
```

Now set the two secrets in your fork:

```
# codesign-dev in your fork
gh secret set -e codesign-dev WIN_CODESIGN_PFX_B64      -b "$(Get-Content .\out\test-codesign\WIN_CODESIGN_PFX_B64.txt -Raw)"
gh secret set -e codesign-dev WIN_CODESIGN_PFX_PASSWORD -b "$(Get-Content .\out\test-codesign\WIN_CODESIGN_PFX_PASSWORD.txt -Raw)"

# Optional: codesign-prod in your fork for full E2E testing
gh secret set -e codesign-prod WIN_CODESIGN_PFX_B64      -b "$(Get-Content .\out\test-codesign\WIN_CODESIGN_PFX_B64.txt -Raw)"
gh secret set -e codesign-prod WIN_CODESIGN_PFX_PASSWORD -b "$(Get-Content .\out\test-codesign\WIN_CODESIGN_PFX_PASSWORD.txt -Raw)"
```

Run the pipeline
- Push to your fork (branch targeting `develop`) or create a test tag like `v0.0.0-test.1` to exercise the codesign jobs behind the corresponding environments.

Clean up (important!)

```
# Remove test cert from your user store
certutil -user -delstore My <THUMBPRINT>
# Or PowerShell:
Remove-Item -LiteralPath Cert:\CurrentUser\My\<THUMBPRINT> -Force

# Remove temporary secrets from your fork
gh secret delete -e codesign-dev WIN_CODESIGN_PFX_B64
gh secret delete -e codesign-dev WIN_CODESIGN_PFX_PASSWORD
# If used:
gh secret delete -e codesign-prod WIN_CODESIGN_PFX_B64
gh secret delete -e codesign-prod WIN_CODESIGN_PFX_PASSWORD

# Delete local files
Remove-Item .\out\test-codesign\* -Force
```

Scope and rationale
- These certificates are intended only for local/fork testing.
- Never use them to sign release artifacts published from the upstream repository.
- This pattern mirrors the hardened workflow without exposing production secrets.

## DevMode quick links

For icon editor dev-mode work, prefer these entrypoints:

- Workflow overview: `docs/DEV_MODE_WORKFLOW.md`
- Primary tests:
  - `src/tests/LvAddonDevMode.Tests.ps1`
  - `src/tests/IconEditorDevMode.Telemetry.Tests.ps1`
- Tools:
  - `tests/tools/Run-DevMode-Debug.ps1` (VS Code tasks: Local CI Stage 25 DevMode enable/disable/debug)
  - `tests/tools/Show-LastDevModeRun.ps1` (VS Code task: Local CI Show last DevMode run) 

### Standard Pester parameters

When running any of the suites above (locally or in CI) use the same invocation so providers get consistent coverage data:

```pwsh
pwsh -NoLogo -NoProfile -Command "Invoke-Pester -Path <relative/test/file> -CI"
```

- `-Path` makes it explicit which suite is under test (`src/tests/LvAddonDevMode.Tests.ps1`, `src/tests/tools/VendorTools.LVAddonLab.Tests.ps1`, etc.).
- `-CI` enables Pester’s CI mode (structured output, exit codes wired to pass/fail, discovery logging).
- Stick to that `pwsh -NoLogo -NoProfile` shim for parity with GitHub runners and VS Code tasks; it keeps module resolution deterministic across providers.

