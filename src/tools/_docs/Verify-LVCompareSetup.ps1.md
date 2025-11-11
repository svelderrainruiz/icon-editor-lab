# Verify-LVCompareSetup.ps1

**Path:** `tools/Verify-LVCompareSetup.ps1`

## Synopsis
Validate that LabVIEW, LVCompare, and LabVIEWCLI paths are configured on Windows hosts, with an optional CLI probe for extra assurance.

## Description
- Loads `configs/labview-paths.local.json` (falling back to `configs/labview-paths.json`) to discover versioned install roots. When configs are missing, scans canonical locations such as `C:\Program Files\National Instruments\LabVIEW 2023` and uses `Get-Command` to find `LabVIEWCLI.exe`.
- Prints the resolved `LabVIEWExePath`, `LVComparePath`, `LabVIEWCLIPath`, and the config file that provided them. Missing or invalid paths result in warnings plus guidance to run `tools/New-LVCompareConfig.ps1`.
- Returns a custom object containing the three resolved paths so calling scripts can consume them programmatically.
- `-ProbeCli` launches `LabVIEWCLI.exe --help`, streaming stdout/stderr and failing if the exit code is non-zero—useful when verifying freshly provisioned runners.
- Intended for self-hosted Windows agents; will throw immediately if run on non-Windows platforms.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `ProbeCli` | switch | Off | After validating paths, execute `LabVIEWCLI.exe --help` and fail if it does not respond. |

## Outputs
- Console summary of resolved paths and config source.
- Returns `[pscustomobject]` with `LabVIEWExePath`, `LVComparePath`, `LabVIEWCLIPath`, `ConfigSource`.

## Exit Codes
- `0` — All required paths exist (and CLI probe succeeded, if requested).
- `1` — One or more paths missing or invalid.
- Other non-zero values bubble up from JSON parsing or CLI probe failures.

## Related
- `tools/New-LVCompareConfig.ps1`
- `docs/LABVIEW_GATING.md`
