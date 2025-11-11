# Invoke-LintDotSourcing.ps1

**Path:** `tools/Invoke-LintDotSourcing.ps1`

## Synopsis
Safe wrapper for the dot-sourcing linter (`tools/Lint-DotSourcing.ps1`) that runs it when present and skips gracefully when missing.

## Description
- Looks for `tools/Lint-DotSourcing.ps1` relative to the current workspace and, if found, runs it via `pwsh -File ... -WarnOnly`.
- If the lint script is absent (e.g., stripped in limited environments), emits a warning and exits 0 instead of failing the pipeline.
- Used by hook scripts and CI tasks to ensure dot-sourcing best practices without hard failures when the full lint suite isn’t available.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| _none beyond the standard bootstrap params_ |  |  | The script simply calls `tools/Lint-DotSourcing.ps1 -WarnOnly` when present. |

## Exit Codes
- Mirrors the linter’s exit code when present; returns `0` when the script is missing.

## Related
- `tools/Lint-DotSourcing.ps1`
- `tools/hooks/scripts/pre-commit.ps1`
