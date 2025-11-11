# pre-commit.ps1

**Path:** `tools/hooks/scripts/pre-commit.ps1`

## Synopsis
Validates staged PowerShell files before committing by running PSScriptAnalyzer plus local lint rules.

## Description
- Accepts the staged file list from Husky (or reads `HOOKS_STAGED_FILES_JSON` when invoked via Git hooks) and filters for `.ps1`, `.psm1`, `.psd1`.
- When PSScriptAnalyzer is installed, runs it with `Severity Error,Warning` and fails the commit if any findings remain.
- Always runs `tools/Lint-InlineIfInFormat.ps1` and `tools/Lint-DotSourcing.ps1 -WarnOnly` to enforce repo-specific style.

### Parameters
| Name | Type | Notes |
| --- | --- | --- |
| `StagedFiles` | string[] | Optional explicit list; otherwise derived from `HOOKS_STAGED_FILES_JSON`. |

## Exit Codes
- `0` – All analyzers passed or no PowerShell files staged.
- `!=0` – Analyzer or lint failures; commit should be aborted.

## Related
- `tools/hooks/scripts/pre-push.ps1`
- `tools/PrePush-Checks.ps1`
