# Close-LabVIEW.ps1

**Path:** `tools/Close-LabVIEW.ps1`

## Synopsis
Gracefully close a LabVIEW instance via the provider-agnostic `LabVIEWCli.psm1` abstraction (LabVIEWCLI today, g-cli in the future).

## Description
- Imports `LabVIEWCli.psm1` and builds the correct parameter set (`labviewPath`, `labviewVersion`, `labviewBitness`).
- Optionally overrides `LABVIEWCLI_PATH` for the duration of the call (`-LabVIEWCliPath`) and allows forcing a specific provider via `-Provider`.
- Runs `Invoke-LVOperation -Operation CloseLabVIEW`, emits the command/provider used, and treats “no connection” errors as success (already closed).
- Supports a `-Preview` mode that returns the resolved command without executing it.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `LabVIEWExePath` | string | Resolved automatically | Explicit path to `LabVIEW.exe`. |
| `MinimumSupportedLVVersion` | string | — | Used when resolving LabVIEW path (e.g., `2023`). |
| `SupportedBitness` | string (`32`,`64`) | — | Bitness for auto resolution. |
| `LabVIEWCliPath` | string | — | Override `LabVIEWCLI.exe` path (sets `LABVIEWCLI_PATH`). |
| `Provider` | string | `auto` | Force a specific CLI provider if needed. |
| `Preview` | switch | Off | Show the command without closing LabVIEW. |

## Exit Codes
- `0` — LabVIEW is closed (or was already closed).
- `1` — Provider failed; see error message for details.

## Related
- `tools/Close-LVCompare.ps1`
- `tools/Detect-RogueLV.ps1`
- `docs/LABVIEW_GATING.md`
