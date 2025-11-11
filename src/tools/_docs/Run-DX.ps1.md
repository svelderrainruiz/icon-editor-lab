# Run-DX.ps1

**Path:** `tools/Run-DX.ps1`

## Synopsis
Executes either the Pester suite or the TestStand compare harness with “DX” conventions (suppressed UI, console annotations, rogue process sweeps) and writes telemetry under `tests/results`.

## Description
- `-Suite Pester` (default) runs `Invoke-Pester` with optional integration tags; `-Suite TestStand` runs `tools/TestStand-CompareHarness.ps1` with the provided VI paths.
- Applies DX environment toggles (suppressed UI, idle waits, console levels), records child-process snapshots before/after the run, and warns if LabVIEW/LVCompare/VIPM processes remain.
- Supports timeouts (`-TimeoutMinutes`/`-TimeoutSeconds`), early termination (`-ContinueOnTimeout`), LVCompare flag overrides, warmup modes, `-UseRawPaths`, and convenient extras like `-RenderReport`, `-OpenReport`, `-CloseLabVIEW`, `-CloseLVCompare`.

### Parameters (subset)
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Suite` | string (`Pester`,`TestStand`) | `Pester` |
| `ResultsPath` | string | `tests/results` |
| `IncludeIntegration` | switch | Include integration-tagged Pester tests. |
| `IncludePatterns` | string[] | Filter which tests to run. |
| `TimeoutMinutes` / `TimeoutSeconds` | double | 0 (disabled) | Applies to both Pester and TestStand runs. |
| `ContinueOnTimeout` | switch | Don’t fail when timeout occurs (still emits warnings). |
| `BaseVi` / `HeadVi` | string | required when `Suite=TestStand`. |
| `LabVIEWExePath`, `LVComparePath` | string | Auto-resolved if omitted. |
| `OutputRoot` | string | `tests/results/teststand-session` |
| `Flags` | string[] | Additional LVCompare flags; `-ReplaceFlags` to override defaults. |
| `NoiseProfile` | string (`full`,`legacy`) | `full` |
| `Warmup` | string (`detect`,`spawn`,`skip`) | `detect` |
| `RenderReport`, `CloseLabVIEW`, `CloseLVCompare`, `OpenReport`, `UseRawPaths` | switch | TestStand-only toggles. |

## Outputs
- Results under `ResultsPath` (Pester) or `OutputRoot/<session>` (TestStand), plus DX console annotations and rogue process warnings.

## Related
- `tools/TestStand-CompareHarness.ps1`
- `tools/Run-VICompareSample.ps1`
