# Invoke-CompareCli.ps1

**Path:** `tools/Invoke-CompareCli.ps1`

## Synopsis
Runs the compare CLI category suites (dispatcher, fixtures, schema, etc.) via `Invoke-PesterTests.ps1` with category-specific include patterns and integration-mode handling.

## Description
- Accepts a `-Category` (dispatcher, fixtures, schema, comparevi, loop, psummary, workflow, etc.) and maps it to a set of include patterns used when running `tools/Invoke-PesterTests.ps1`.
- Handles `-IntegrationMode include|exclude|auto` and the legacy `-IncludeIntegration` flag; when in auto mode, it inspects environment variables to decide whether to include integration tests.
- Writes results under `-ResultsRoot/<Category>` (default `tests/results/categories/<category>`) and emits a `compare-cli-run/v1` summary (`cli-run.json`) with integration decisions, exit code, and Pester summary metrics.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Category` | string (required) | - | Determines which test files/patterns are included. |
| `IntegrationMode` | string (`auto`,`include`,`exclude`) | `include` | Controls integration test inclusion (auto uses env heuristics). |
| `IncludeIntegration` | string (deprecated) | - | Legacy flag; use `-IntegrationMode`. |
| `ResultsRoot` | string | `tests/results/categories` | Root where per-category outputs are stored. |

## Outputs
- `<ResultsRoot>/<Category>/cli-run.json` (`compare-cli-run/v1`) plus the usual Pester summary files (`pester-summary.json`, log artifacts).

## Exit Codes
- Passes through the Pester exit code returned by `Invoke-PesterTests.ps1`.

## Related
- `tools/Invoke-PesterTests.ps1`
- `docs/LVCOMPARE_LAB_PLAN.md`
