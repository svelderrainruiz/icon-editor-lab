# Lint-DotSourcing.ps1

**Path:** `tools/Lint-DotSourcing.ps1`

## Synopsis
Searches PowerShell files for relative dot-sourcing statements (`. ./file.ps1`) and flags them with GitHub Actions-style annotations.

## Description
- Recursively scans `*.ps1`, `*.psm1`, `*.psd1` under the current repo (skipping `node_modules`).
- Detects lines that start with `.` followed by relative paths (`./`, `../`, etc.) and emits `::error` annotations pointing to the file and line number.
- `-WarnOnly` downgrades annotations to warnings and allows the script to exit 0; otherwise, it exits `2` when violations are found.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `WarnOnly` | switch | Off | Emit warnings instead of errors and exit 0 even when violations exist. |

## Exit Codes
- `0` when no violations (or when `-WarnOnly` is set).
- `2` when violations are detected without `WarnOnly`.

## Related
- `tools/Invoke-LintDotSourcing.ps1`
- `tools/hooks/scripts/pre-commit.ps1`
