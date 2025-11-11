# Lint-InlineIfInFormat.ps1

**Path:** `tools/Lint-InlineIfInFormat.ps1`

## Synopsis
Flags PowerShell format expressions (`"..." -f ...`) that embed inline `if` statements without `$()` wrapping.

## Description
- Recursively scans PowerShell/YAML files (excluding `node_modules`) for lines matching the pattern `-f (if (...))`, which can behave unexpectedly because the inline `if` is evaluated outside `$()`.
- Emits GitHub Actions `::error` annotations pointing to offending lines and exits with code `2` when violations are found.
- Used in pre-commit hooks / CI to enforce safer formatting patterns (precompute values or wrap inline `if` in `$()`).

## Exit Codes
- `0` when no violations.
- `2` when at least one violation is detected.

## Related
- `tools/hooks/scripts/pre-commit.ps1`
- `tools/Invoke-LintDotSourcing.ps1`
