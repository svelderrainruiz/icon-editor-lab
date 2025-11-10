# Run-VICompareSample.ps1

**Path:** `tools/Run-VICompareSample.ps1`

## Synopsis
Runs a quick VI Compare smoke test using `tools/TestStand-CompareHarness.ps1`, producing `compare-report.html` and capture artifacts under `tests/results/teststand-session/<label>`.

## Description
- Resolves the provided base/head VI paths (relative paths default to bundled MissingInProject VIs), confirms the LabVIEW executable exists, and prepares an output directory under `OutputRoot/<Label>`.
- Invokes `TestStand-CompareHarness.ps1` with sensible defaults (`-Warmup skip`, `-RenderReport`, `-CloseLabVIEW`, `-CloseLVCompare`, `-SameNameHint`) so the run generates a full compare report but avoids extra warmups.
- `-DryRun` prints the command line without executing the harness—helpful when verifying machine setup.

### Parameters
| Name | Type | Default |
| --- | --- | --- |
| `LabVIEWPath` | string | `C:\Program Files\National Instruments\LabVIEW 2025\LabVIEW.exe` |
| `BaseVI` | string | `vendor/icon-editor/.github/actions/missing-in-project/MissingInProject.vi` |
| `HeadVI` | string | `vendor/icon-editor/.github/actions/missing-in-project/MissingInProjectCLI.vi` |
| `OutputRoot` | string | `tests/results/teststand-session` |
| `Label` | string | `vi-compare-smoke` |
| `DryRun` | switch | Off |

## Outputs
- Compare harness artifacts (reports, logs, captures) under `tests/results/teststand-session/<label>`.
- Console line pointing to `compare-report.html` when found.

## Related
- `tools/TestStand-CompareHarness.ps1`
- `docs/LVCOMPARE_LAB_PLAN.md`
