# Quick-DispatcherSmoke.ps1

**Path:** `tools/Quick-DispatcherSmoke.ps1`

## Synopsis
Runs a tiny ad-hoc Pester suite via `Invoke-PesterTests.ps1` to validate that the dispatcher works on the current machine/runner.

## Description
- Creates a temporary folder (optionally under `GITHUB_WORKSPACE` or `RUNNER_TEMP`), writes a minimal passing test, and invokes `Invoke-PesterTests.ps1 -TestsPath <temp>` so you can confirm the dispatcher schema output without touching real suites.
- Prints the key fields from `pester-summary.json` and, when `-Raw` is provided, dumps the full JSON.
- `-Keep` leaves the temp folder behind for debugging; otherwise it deletes the folder on success/failure.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Raw` | switch | Off | Also print the raw JSON summary. |
| `Keep` | switch | Off | Don’t delete the temp directory. |
| `ResultsPath` | string | `<temp>/results` | Override output folder (a `pester-summary.json` file is expected). |
| `TestsRoot` | string | auto temp dir | Use an explicit root instead of generating one. |
| `PreferWorkspace` | switch | Off | Prefer `GITHUB_WORKSPACE\.tmp-smoke` for temp files. |

## Outputs
- Console dump of summary metrics and optional raw JSON.
- Temp directories removed unless `-Keep` is set.

## Related
- `Invoke-PesterTests.ps1`
- `docs/LABVIEW_GATING.md`
