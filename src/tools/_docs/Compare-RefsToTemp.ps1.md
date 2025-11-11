# Compare-RefsToTemp.ps1

**Path:** `tools/Compare-RefsToTemp.ps1`

## Synopsis
Exports the same VI from two git refs, runs LVCompare, and records exec/summary JSON plus optional HTML reports and leak telemetry.

## Description
- Supports two parameter sets:
  - `-Path` – direct relative/absolute path to the VI inside the repo.
  - `-ViName` – resolves the VI by name under each ref before exporting.
- Uses `git show <ref>:<path>` to hydrate `%TEMP%\refcmp-*/Base.vi` and `Head.vi`, capturing byte counts and SHA256 hashes to flag expected diffs up front.
- Loads `scripts/CompareVI.psm1`; when `-Detailed` or `-RenderReport` is set it shells out to `Invoke-LVCompare.ps1` so `lvcompare-capture.json`, stdout/stderr, screenshots, and formatted reports are produced under `<ResultsDir>/<OutName>-artifacts/`.
- LVCompare behavior is tunable via `-LvCompareArgs`, `-ReplaceFlags`, `-LvComparePath`, `-LabVIEWExePath`, or a fully custom `-InvokeScriptPath`.
- Optional leak telemetry: `-LeakCheck` (with `-LeakGraceSeconds` and `-LeakJsonPath`) propagates through to the Invoke script and copies `lvcompare-leak.json` into the artifact bundle.
- Outputs always include:
  - `<ResultsDir>/<OutName>-exec.json` (`compare-exec/v1` with CLI path, args, duration, capture metadata).
  - `<ResultsDir>/<OutName>-summary.json` (`ref-compare-summary/v1` with ref names, hashes, CLI diff flag, artifact pointers).
  - Optional `<OutName>-artifacts/` (report, capture, stdout/stderr, `cli-images/`, leak JSON).
- With `-FailOnDiff`, LVCompare exit code `1` is treated as fatal; otherwise the script exits `0` even when diffs occur so callers can inspect the summary.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Path` | string | required (ByPath) | VI path to export from each ref. |
| `ViName` | string | required (ByName) | Script resolves the VI path based on name. |
| `RefA` / `RefB` | string | required | Git SHA/ref/tag used to export Base/Head. |
| `ResultsDir` | string | `tests/results/ref-compare` | Destination for exec/summary JSON and artifacts. |
| `OutName` | string | sanitized VI name | File prefix for outputs. |
| `Detailed` | switch | Off | Emit capture/report assets. |
| `RenderReport` | switch | Off | Forces HTML report emission. |
| `ReportFormat` | string (`html`,`xml`,`text`) | `html` | Format stored under the artifact root. |
| `LvCompareArgs` | string | - | Extra LVCompare flags (tokenized). |
| `ReplaceFlags` | switch | Off | Replace default LVCompare flags entirely. |
| `LvComparePath` / `LabVIEWExePath` | string | auto | Explicit CLI/LabVIEW executables. |
| `InvokeScriptPath` | string | auto-detected | Custom `Invoke-LVCompare.ps1` path. |
| `LeakCheck` | switch | Off | Enables CLI leak detection; see also `LeakGraceSeconds`, `LeakJsonPath`. |
| `FailOnDiff` | switch | Off | Throw if LVCompare reports differences. |
| `Quiet` | switch | Off | Suppress verbose console output. |

## Exit Codes
- `0` when comparison succeeds (diffs allowed unless `-FailOnDiff`).
- `1` when `-FailOnDiff` is set and LVCompare returned a diff.
- Other non-zero codes bubble up for git/LVCompare failures or capture issues.

## Related
- `tools/Compare-VIHistory.ps1`
- `tools/Run-HeadlessCompare.ps1`
- `docs/LVCOMPARE_LAB_PLAN.md`
