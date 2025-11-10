# PrePush-Checks.ps1

**Path:** `tools/PrePush-Checks.ps1`

## Synopsis
Runs repo-level validations (actionlint, remote-ref guard, LabVIEW.exe usage scan) before allowing a push.

## Description
- Ensures remote refs are unambiguous via `tools/Assert-NoAmbiguousRemoteRefs.ps1`.
- Locates (or installs) `actionlint` using `Resolve-ActionlintPath` / `tools/dl-actionlint.sh`, then lints every workflow under `.github/workflows`.
- After linting, scans the repo for direct `LabVIEW.exe` invocations to enforce the LabVIEWCLI/G-cli contract.
- Designed to run locally (`pre-push.ps1`) and in CI; optional flags let you pin the actionlint version or skip auto-install.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `ActionlintVersion` | string | `1.7.7` | Version to install when missing. |
| `InstallIfMissing` | bool | `$true` | Attempt to install actionlint when not found under `bin/`. |

## Exit Codes
- `0` – All checks passed.
- `!=0` – Guard, lint, or LabVIEW scan failed (message printed to stderr).

## Related
- `tools/hooks/scripts/pre-push.ps1`
- `tools/dl-actionlint.sh`
- `tools/Assert-NoAmbiguousRemoteRefs.ps1`
