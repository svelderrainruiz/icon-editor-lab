# Icon Editor Lab

Tooling, pipelines, and tests that support the Icon Editor lab experience.

## Release

1. Ensure the latest `develop` commit is green (CI + coverage gates >= 75%).
2. Tag the commit with the next semantic version (e.g., `git tag v0.2.0 && git push origin v0.2.0`).
3. The `release.yml` workflow runs automatically for `v*` tags or via `workflow_dispatch`, executes the Pester suite, enforces the coverage floors, uploads test/coverage artifacts, and creates the GitHub Release with those artifacts attached.

## Local Git hooks (optional)

- Pre-commit path policy guard: `tools/git-hooks/Invoke-PreCommitChecks.ps1` scans staged PowerShell files for hard-coded drive-letter paths and fails the commit if found.
- Pre-push test gate: `tools/git-hooks/Invoke-PrePushChecks.ps1` runs `Invoke-Pester -Path tests -CI` and writes NUnit XML under `artifacts/test-results`.
- One-liner setup: `pwsh -NoLogo -NoProfile -File tools/git-hooks/Install-GitHooks.ps1` (creates `.git/hooks/pre-commit` and `.git/hooks/pre-push` that invoke the scripts above).
- To temporarily skip locally, set `ICONEDITORLAB_SKIP_PRECOMMIT=1` or `ICONEDITORLAB_SKIP_PREPUSH=1`.
