# Compare-VIHistory.ps1

**Path:** `tools/Compare-VIHistory.ps1`

## Synopsis
Walks a VI’s git history (including optional merge parents), runs `Compare-RefsToTemp.ps1` for each commit pair/mode, and produces manifests plus a rendered history report.

## Description
- Input: `-TargetPath` (relative VI path) and a history window (`-StartRef` default `HEAD`, optional `-EndRef`). The script discovers commit pairs that touched the VI and, when `-IncludeMergeParents` is set, branches into merge parents so backports are inspected as well.
- Noise handling:
  - `-NoisePolicy include|collapse|skip` controls how pairs with attribute-only or UI-only edits are represented.
  - `-MaxPairs` bounds the number of comparisons overall, while `-MaxSignalPairs` limits the number of “real diff” pairs kept after noise collapsing.
- Modes (`-Mode default,attributes,front-panel,block-diagram,...`) change the LVCompare flag set so separate passes can focus on attributes, front-panel geometry, terminal maps, etc. Fine-grained flags (`-FlagNoAttr`, `-FlagNoFp`, `-FlagNoFpPos`, `-FlagNoBdCosm`, `-ForceNoBd`, `-AdditionalFlags`) let you override the presets or match the Scenario 1–4 guardrails from `docs/LVCOMPARE_LAB_PLAN.md`.
- Each pair/mode is run via `tools/Compare-RefsToTemp.ps1`, respecting LVCompare overrides (`-LvCompareArgs`, `-ReplaceFlags`, `-InvokeScriptPath`, `-ReportFormat`, `-RenderReport`, `-KeepArtifactsOnNoDiff`). Failures can halt immediately with `-FailFast` or continue gathering data.
- Outputs under `<ResultsDir>/<OutPrefix or target slug>/` include:
  - `mode-*/manifest.json` (one per mode) with every comparison result and artifact pointers.
  - `history-context.json`, `manifest.json`, and summary tables capturing signal vs noise counts.
  - Rendered Markdown + HTML history report via `tools/Render-VIHistoryReport.ps1` (fallback content is produced if rendering fails).
  - Optional per-mode artifacts from `Compare-RefsToTemp` (HTML reports, capture JSON, cli-images) depending on the flags used.
- Integrates with CI by writing GitHub output variables (`history-report-md/html`, `mode manifests`) and appending status to `GITHUB_STEP_SUMMARY`. `-FailOnDiff` throws when any pair produced a diff after noise filtering.

### Parameters (highlights)
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `TargetPath` | string (required) | - | VI path to evaluate. |
| `StartRef` / `EndRef` | string | `HEAD` / *none* | History window (inclusive). |
| `MaxPairs` | int | *unbounded* | Hard stop on total comparisons. |
| `MaxSignalPairs` | int | `2` | Maximum “diff” pairs retained after noise handling; set 0 to disable. |
| `NoisePolicy` | string (`include`,`collapse`,`skip`) | `collapse` | Controls whether noise pairs appear in the manifest. |
| `Mode` | string[] | `default` | Choose one or more LVCompare flag presets (`attributes`, `front-panel`, `block-diagram`, etc.). |
| `FlagNoAttr` / `FlagNoFp` / `FlagNoFpPos` / `FlagNoBdCosm` / `ForceNoBd` | bool | see script | Fine-tune LVCompare filters beyond the preset. |
| `AdditionalFlags`, `LvCompareArgs`, `ReplaceFlags` | string | - | Extra LVCompare CLI switches (parsed and merged). |
| `ResultsDir` | string | `tests/results/ref-compare/history` | Root for manifests/reports. |
| `OutPrefix` | string | derived from VI name | Folder prefix (useful when batching). |
| `ManifestPath` | string | auto | Override aggregate manifest location. |
| `Detailed`, `RenderReport`, `ReportFormat`, `KeepArtifactsOnNoDiff` | switches/string | - | Passed through when invoking `Compare-RefsToTemp`. |
| `FailFast` | switch | Off | Stop at first fatal error even if retries remain. |
| `FailOnDiff` | switch | Off | Throw when any comparison reports a diff. |
| `IncludeMergeParents` | switch | Off | Crawl merge parents in addition to the first-parent chain. |
| `GitHubOutputPath` / `StepSummaryPath` | string | env defaults | Where to write reusable CI metadata. |

## Exit Codes
- `0` when the history sweep completed (diffs allowed unless `-FailOnDiff`).
- `1` when `Compare-RefsToTemp` encounters a fatal error or a diff is treated as fatal (`-FailOnDiff`).
- Other codes bubble up from git/PowerShell failures.

## Related
- `tools/Compare-RefsToTemp.ps1`
- `tools/Render-VIHistoryReport.ps1`
- `docs/LVCOMPARE_LAB_PLAN.md`
