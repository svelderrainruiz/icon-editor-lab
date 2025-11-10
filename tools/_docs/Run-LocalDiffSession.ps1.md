# Run-LocalDiffSession.ps1

**Path:** `tools/Run-LocalDiffSession.ps1`

## Synopsis
Wraps `Verify-LocalDiffSession.ps1` to compare two VIs locally, capture the artifacts, and optionally archive the results and verify VI Server configuration.

## Description
- Accepts base/head VI paths plus a set of optional switches that mirror the compare harness (`Mode`, `Stateless`, `AutoConfig`, `RenderReport`, `NoiseProfile`, `UseStub`).
- Can probe VI Server settings (`server.tcp.enabled`) by resolving `LabVIEW.exe` via `VendorTools.psm1` when `-CheckViServer` is left enabled.
- After `Verify-LocalDiffSession` runs, copies artifacts into `ArchiveDir` and creates a zip (`ArchiveZip`) for easy sharing.

### Parameters (subset)
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `BaseVi` / `HeadVi` | string | required | VI paths to compare. |
| `Mode` | string (`normal`,`cli-suppressed`,`git-context`,`duplicate-window`) | `normal` | Match modes supported by `Verify-LocalDiffSession`. |
| `ResultsRoot` | string | - | Override compare results directory. |
| `ProbeSetup`, `AutoConfig`, `Stateless`, `RenderReport`, `UseStub` | switch | Off | Forwarded to the verify script. |
| `LabVIEWVersion` / `LabVIEWBitness` | string | - | Hints for candidate LabVIEW resolution. |
| `NoiseProfile` | string (`full`,`legacy`) | `full` | Passed to LVCompare. |
| `CheckViServer` | switch | On | Warn when VI Server isn’t enabled for the detected LabVIEW exe. |
| `ArchiveDir` | string | `tests/results/_agent/local-diff/latest` | Destination copy of artifacts. |
| `ArchiveZip` | string | `tests/results/_agent/local-diff/latest.zip` | Zip path. |

## Outputs
- Returns the session object from `Verify-LocalDiffSession` and writes archives to the paths above.

## Related
- `tools/Verify-LocalDiffSession.ps1`
- `tools/Parse-CompareExec.ps1`
