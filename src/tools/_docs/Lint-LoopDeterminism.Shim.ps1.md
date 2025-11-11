# Lint-LoopDeterminism.Shim.ps1

**Path:** `tools/Lint-LoopDeterminism.Shim.ps1`

## Synopsis
Convenience wrapper that normalizes path/glob arguments before calling `Lint-LoopDeterminism.ps1`, handling mixed positional args and optional flags safely.

## Description
- Accepts a combination of `-Paths`, `-PathsList`, and trailing positional arguments (globs or directories). Expands them into a unique file list (PowerShell/YAML) and skips missing tokens with notices.
- Coerces `-MaxIterations`/`-IntervalSeconds` even when callers pass strings, then runs the core linter with the same threshold parameters and optional `-FailOnViolation` flag.
- Emits the same exit code as the inner script, so callers can use the shim in CI without worrying about path quoting.

### Parameters
| Name | Type | Notes |
| --- | --- | --- |
| `Paths` | string[] | Direct file paths or globs. |
| `PathsList` | string | Semicolon/whitespace-separated list of paths/globs. |
| `Rest` | string[] | Captures any additional positional args (ValueFromRemainingArguments). |
| `MaxIterations` | object | Coerced to int (default 5). |
| `IntervalSeconds` | object | Coerced to double (default 0). |
| `AllowedStrategies` | string[] | Passed to the core linter (default `Exact`). |
| `FailOnViolation` | switch | Exits 3 when violations exist. |

## Exit Codes
- Mirrors `Lint-LoopDeterminism.ps1` (0 = clean, 3 when `-FailOnViolation` and issues exist).

## Related
- `tools/Lint-LoopDeterminism.ps1`
