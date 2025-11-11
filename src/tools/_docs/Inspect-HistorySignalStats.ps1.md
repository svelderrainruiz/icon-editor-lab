# Inspect-HistorySignalStats.ps1

**Path:** `tools/Inspect-HistorySignalStats.ps1`

## Synopsis
Runs `Compare-VIHistory.ps1` with the LVCompare stub to measure signal/noise ratios for a given VI path and outputs a summary of processed pairs.

## Description
- Invokes `tools/Compare-VIHistory.ps1` against `-TargetPath` and `-StartRef`, using `tests/stubs/Invoke-LVCompare.stub.ps1` so no actual LVCompare session is needed.
- Writes results under `tests/results/_agent/history-stub` (or `-ResultsDir`) and prints a summary including total processed commits, signal diffs, and per-mode stats. Returns the summary object for scripting.
- Useful for verifying `MaxSignalPairs`, `NoisePolicy`, and other history settings without touching real VI artifacts.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `TargetPath` | string | `fixtures/vi-stage/bd-cosmetic/Head.vi` | VI path to analyze. |
| `StartRef` | string | `HEAD` | Starting commit for history traversal. |
| `MaxPairs` | int | `6` | Max comparisons per mode. |
| `MaxSignalPairs` | int | `2` | Stop after this many signal diffs. |
| `NoisePolicy` | string (`include`,`collapse`,`skip`) | `collapse` | How noise-only diffs are treated. |
| `ResultsDir` | string | `tests/results/_agent/history-stub` | Destination for manifest + artifacts. |
| `RenderReport` | switch | Off | Request HTML report rendering. |
| `KeepArtifacts` | switch | Off | Preserve compare artifacts even on success. |
| `Quiet` | switch | Off | Suppress console summary. |

## Outputs
- Console summary and `[pscustomobject]` with aggregate/mode stats (manifest paths, processed diffs, etc.).

## Exit Codes
- Non-zero when Compare-VIHistory fails or the manifest can’t be generated.

## Related
- `tools/Compare-VIHistory.ps1`
- `tests/stubs/Invoke-LVCompare.stub.ps1`
