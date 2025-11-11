# Invoke-LVCompare.ps1

**Path:** `tools/Invoke-LVCompare.ps1`

## Synopsis
Deterministic wrapper around LVCompare.exe that produces capture JSON, optional reports, and leak telemetry for a single VI comparison.

## Description
- Resolves LabVIEW/LVCompare paths (or uses overrides via `-LabVIEWExePath`, `-LVComparePath`) and shells out through the capture pipeline so artifacts are consistent with CI.
- Artifacts under `-OutputDir` (default `tests/results/single-compare`):
  - `lvcompare-capture.json` (`lvcompare-capture-v1`)
  - `compare-report.html|xml|txt` depending on `-ReportFormat` / `-RenderReport`
  - `lvcompare-stdout.txt`, `lvcompare-stderr.txt`, `lvcompare-exitcode.txt`
  - Optional leak summary when `-LeakCheck`
- `-Flags` append extra LVCompare flags; `-ReplaceFlags` skips defaults; `-NoiseProfile legacy` reenables the historical ignore bundle (`-noattr -nofp -nofppos -nobd -nobdcosm`).
- `-JsonLogPath` writes NDJSON crumbs; `-Summary` prints console summary and appends to `$GITHUB_STEP_SUMMARY`.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `BaseVi` / `HeadVi` | string (required) | - | VI paths to compare. |
| `LabVIEWExePath` | string | auto | Explicit LabVIEW executable (`-LabVIEWPath` alias). |
| `LVComparePath` | string | auto | Explicit LVCompare executable. |
| `LabVIEWBitness` | string (`32`,`64`) | `64` | Overrides when resolving LabVIEW CLI. |
| `Flags` | string[] | - | Additional LVCompare flags. |
| `ReplaceFlags` | switch | Off | Replace default flags entirely. |
| `NoiseProfile` | string (`full`,`legacy`) | `full` | Which ignore bundle to use when not replacing flags. |
| `OutputDir` | string | `tests/results/single-compare` | Destination for artifacts. |
| `RenderReport` | switch | Off | Force HTML report even if `-ReportFormat` not set. |
| `ReportFormat` | string (`html`,`html-single`,`xml`,`text`) | `html` | Report type + file name. |
| `JsonLogPath` | string | - | NDJSON crumb log path. |
| `LeakCheck` | switch | Off | Capture remaining LabVIEW/LVCompare PIDs. |
| `LeakJsonPath` | string | `compare-leak.json` | Leak summary path when `-LeakCheck`. |
| `LeakGraceSeconds` | double | `0.5` | Delay before leak check. |
| `CaptureScriptPath` | string | internal | Custom capture script (testing). |
| `Summary` | switch | Off | Print summary and append to step summary. |
| `TimeoutSeconds` | int? | repo defaults | Override compare timeout. |

## Exit Codes
- Propagates LVCompare/capture exit code (0 match, 1 diff, >1 error).

## Related
- `tools/Compare-RefsToTemp.ps1`
- `tools/Compare-VIHistory.ps1`
