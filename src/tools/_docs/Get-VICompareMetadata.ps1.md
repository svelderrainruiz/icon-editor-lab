# Get-VICompareMetadata.ps1

**Path:** `tools/Get-VICompareMetadata.ps1`

## Synopsis
Runs LVCompare on a VI pair (via `Invoke-LVCompare.ps1`) and extracts metadata such as diff categories, headings, and included attributes into a JSON report.

## Description
- Invokes `tools/Invoke-LVCompare.ps1` (or a custom scriptblock via `-InvokeLVCompare`) to produce compare artifacts under a temp directory.
- Parses `compare-report.html` to capture headings, difference categories, and attribute toggles, and stores the results alongside LVCompare exit status.
- Writes the metadata JSON to `-OutputPath` and returns it to the caller, enabling downstream tooling to summarize compare results without re-rendering.
- Supports custom LVCompare flags via `-Flags` and `-ReplaceFlags`, plus the `-NoiseProfile` (`full` or `legacy`) toggle inherited from other compare scripts.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `BaseVi` | string (required) | - | Baseline VI path. |
| `HeadVi` | string (required) | - | Head VI path. |
| `OutputPath` | string (required) | - | Destination JSON file. |
| `Flags` | string[] | - | Extra LVCompare flags (passed through to Invoke-LVCompare). |
| `ReplaceFlags` | switch | Off | Replace default flags entirely. |
| `NoiseProfile` | string (`full`,`legacy`) | `full` | Selects ignore bundle when not replacing flags. |
| `InvokeLVCompare` | scriptblock | auto | Custom compare invoker (used in tests). |

## Outputs
- JSON object containing compare status, exit code, report/capture paths, diff categories/headings/details, and attribute inclusion flags.

## Exit Codes
- Non-zero when compare artifacts can’t be generated or parsed; otherwise returns the metadata object (the JSON includes LVCompare’s own exit code).

## Related
- `tools/Invoke-LVCompare.ps1`
- `docs/LVCOMPARE_LAB_PLAN.md`
