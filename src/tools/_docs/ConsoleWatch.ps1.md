# ConsoleWatch.ps1

**Path:** `tools/ConsoleWatch.ps1`

## Synopsis
Entry script that imports `ConsoleWatch.psm1` so `Start-ConsoleWatch` / `Stop-ConsoleWatch` are available for CI jobs that need to monitor console process spawns.

## Description
- Thin wrapper that sets strict mode and imports the module; call `.\tools\ConsoleWatch.ps1` (dot-source or via `pwsh -File`) to make `Start-ConsoleWatch`/`Stop-ConsoleWatch` available in the current session.
- The actual watch functionality lives in `ConsoleWatch.psm1`; see that doc for parameters and outputs.

## Related
- `tools/ConsoleWatch.psm1`
- `tools/ConsoleUx.psm1`
