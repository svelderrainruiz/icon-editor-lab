Testing signed workflows in a fork (no prod secrets)

When to use
- Run this when you want to exercise the `codesign-*` jobs in your fork without access to the org’s production code‑signing secrets. It keeps the workflow identical while using a throwaway certificate.

Generate a test certificate (Windows + PowerShell 7)
```
pwsh -File tools/Generate-TestCodeSignCert.ps1 -OutDir .\out\test-codesign -EmitJson -EmitEnv
```
This creates a self‑signed code‑signing cert (valid ~14 days), exports a PFX, and writes:
- `out/test-codesign/WIN_CODESIGN_PFX_B64.txt`
- `out/test-codesign/WIN_CODESIGN_PFX_PASSWORD.txt`
- optional: `secrets.json`, `.env`

Create environments (if missing) in your fork
```
gh api repos/:owner/:repo/environments -f name=codesign-dev
gh api repos/:owner/:repo/environments -f name=codesign-prod
```

Add environment secrets in your fork
```
gh secret set -e codesign-dev  WIN_CODESIGN_PFX_B64      -b "$(Get-Content .\out\test-codesign\WIN_CODESIGN_PFX_B64.txt -Raw)"
gh secret set -e codesign-dev  WIN_CODESIGN_PFX_PASSWORD -b "$(Get-Content .\out\test-codesign\WIN_CODESIGN_PFX_PASSWORD.txt -Raw)"

# Optional: for full E2E testing
gh secret set -e codesign-prod WIN_CODESIGN_PFX_B64      -b "$(Get-Content .\out\test-codesign\WIN_CODESIGN_PFX_B64.txt -Raw)"
gh secret set -e codesign-prod WIN_CODESIGN_PFX_PASSWORD -b "$(Get-Content .\out\test-codesign\WIN_CODESIGN_PFX_PASSWORD.txt -Raw)"
```

Run the pipeline
- Push to a branch targeting `develop`, or create a test tag like `v0.0.0-test.1` to exercise the `codesign-prod` job.

Cleanup (important!)
```
# Preview (no changes)
pwsh -File tools/CLEANUP-TestCodeSign.ps1 -OutDir .\out\test-codesign -WhatIf

# Remove cert + generated files (scan output folder)
pwsh -File tools/CLEANUP-TestCodeSign.ps1 -OutDir .\out\test-codesign

# Or remove by explicit thumbprint
pwsh -File tools/CLEANUP-TestCodeSign.ps1 -Thumbprint ABCDEF1234567890ABCDEF1234567890ABCDEF12

# Also delete the env secrets in this repo
pwsh -File tools/CLEANUP-TestCodeSign.ps1 -OutDir .\out\test-codesign -DeleteGhSecrets -Environments codesign-dev,codesign-prod
```

Scope
- These certificates are intended only for local/fork testing. Never use them to sign release artifacts from the upstream repository.

