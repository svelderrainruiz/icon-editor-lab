# New-LVCompareConfig.ps1

**Path:** `tools/New-LVCompareConfig.ps1`

## Synopsis
Interactive (or scripted) helper that writes `configs/lvcompare-config.json` with resolved LabVIEW, LVCompare, and LabVIEWCLI paths, optionally adding version/bitness metadata.

## Description
- Loads `VendorTools.psm1`, inspects `configs/labview-paths*.json`, env vars, and defaults to gather candidate paths for LabVIEW/LVCompare/LabVIEWCLI. Prompts the user unless `-NonInteractive` is set and all parameters are supplied.
- Supports `-Probe` to immediately run `tools/Verify-LVCompareSetup.ps1 -ProbeCli` after writing the config.
- When `-Version`/`-Bitness` are provided (or inferred from the selected LabVIEW path), the script populates the `versions.<version>.<bitness>` section with the chosen executables so downstream scripts can resolve the correct CLI for each LabVIEW release.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `OutputPath` | string | `configs/lvcompare-config.json` | Destination config file. |
| `NonInteractive` | switch | Off | Require all paths via parameters (no prompts). |
| `Force` | switch | Off | Overwrite existing config without prompting. |
| `Probe` | switch | Off | Run `Verify-LVCompareSetup.ps1 -ProbeCli` after writing. |
| `LabVIEWExePath` | string | auto | Explicit LabVIEW.exe path. |
| `LVComparePath` | string | auto | Explicit LVCompare.exe path. |
| `LabVIEWCLIPath` | string | auto | Explicit LabVIEWCLI.exe path. |
| `Version` | string | inferred | Version key (e.g., `2023`). |
| `Bitness` | string (`32`,`64`) | inferred | Bitness node under the version entry. |

## Outputs
- JSON config describing executable paths plus version metadata; the script echoes the resolved paths and writes the file to `OutputPath`.

## Related
- `tools/Verify-LVCompareSetup.ps1`
- `docs/LVCOMPARE_LAB_PLAN.md`
