# ConsoleUx.psm1

**Path:** `tools/ConsoleUx.psm1`

## Synopsis
UX helper module that standardizes console verbosity via `DX_CONSOLE_LEVEL` and provides lightweight logging helpers.

## Description
- `Get-DxLevel` reads `DX_CONSOLE_LEVEL` (or takes an override) and maps it to one of `quiet|concise|normal|detailed|debug`.
- `Test-DxAtLeast` compares verbosity ranks to gate logging.
- `Write-Dx` emits `[dx]` lines (info/warn/error/debug) honoring the current console level; warnings/errors still surface regardless of level.
- `Write-DxKV` prints sorted key/value pairs (prefix `[dx]` by default) when the console level isn’t `quiet`.
- These helpers are imported by other tooling (ConsoleWatch, Dev-Dashboard, etc.) to keep CLI output consistent across CI logs.

### Exported Functions
| Function | Purpose |
| --- | --- |
| `Get-DxLevel` | Resolve the current verbosity level (env override). |
| `Test-DxAtLeast` | Determine if the console level meets/exceeds a threshold. |
| `Write-Dx` | Print a formatted log line at the requested severity. |
| `Write-DxKV` | Emit structured key/value telemetry respecting verbosity. |

## Related
- `tools/ConsoleWatch.psm1`
- `tools/Dev-Dashboard.psm1`
