# Close-LVCompare.ps1

**Path:** `tools/Close-LVCompare.ps1`

## Synopsis
Launch LVCompare.exe with deterministic flags to ensure the compare process exits cleanly, honoring explicit LabVIEW/LVCompare paths and timeout behavior.

## Description
- Resolves `LabVIEWExePath` and `LVComparePath` using environment variables (`LABVIEW_PATH`, `LVCOMPARE_PATH`, etc.) or canonical installs (`C:\Program Files\National Instruments\Shared\LabVIEW Compare\LVCompare.exe`).
- Runs LVCompare with no-UI flags (`-noattr -nofp -nofppos -nobd -nobdcosm`) unless `-SkipDefaultFlags` is set.
- Accepts optional `BaseVi`/`HeadVi` overrides; otherwise uses environment defaults for “dummy” compares that just close the process.
- Waits up to `TimeoutSeconds` (default 60s) for the process to exit, optionally killing it when `-KillOnTimeout` is set.
- Emits a PSCustomObject describing the invocation (`exitCode`, `labviewPath`, `lvComparePath`, `arguments`, `elapsedSeconds`) and mirrors the LVCompare exit code to `$LASTEXITCODE`.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `LabVIEWExePath` | string | Resolved via env/canonical install | Path passed to `LVCompare.exe -lvpath`. |
| `MinimumSupportedLVVersion` | string | Auto derived | Used when LabVIEW path is not provided. |
| `SupportedBitness` | string (`32`,`64`) | Auto derived | Bitness when constructing the LabVIEW path. |
| `LVComparePath` | string | Canonical install | Override the LVCompare executable path. |
| `BaseVi` / `HeadVi` | string | Environment defaults | Provide explicit VI paths if required. |
| `AdditionalArguments` | string[] | — | Extra CLI switches appended after defaults. |
| `TimeoutSeconds` | int | `60` | Max wait for LVCompare to exit. |
| `KillOnTimeout` | switch | Off | Terminate the process if it exceeds the timeout. |
| `SkipDefaultFlags` | switch | Off | Prevent automatic `-noattr -nofp -nofppos -nobd -nobdcosm`. |

## Exit Codes
- `0` — LVCompare exited cleanly.
- `!=0` — LVCompare reported an error or timed out (see output object for details).

## Related
- `tools/TestStand-CompareHarness.ps1`
- `tools/Run-HeadlessCompare.ps1`
- `docs/LVCOMPARE_LAB_PLAN.md`
