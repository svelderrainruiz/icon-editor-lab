# Lint-LoopDeterminism.ps1

**Path:** `tools/Lint-LoopDeterminism.ps1`

## Synopsis
Ensures CI control loops (workflow YAML, scripts) stay deterministic by flagging disallowed iteration counts, intervals, quantile strategies, and histogram bins.

## Description
- Scans provided `-Paths` (PowerShell/YAML files) for loop-related settings:
  - `loop-max-iterations`, `-LoopIterations`
  - `loop-interval-seconds`, `-LoopIntervalSeconds`
  - `quantile-strategy`, `-QuantileStrategy`
  - `histogram-bins`, `-HistogramBins`
- Default thresholds: max iterations `5`, interval seconds `0`, allowed strategies `Exact`, histogram bins `0`.
- Collects all violations and prints a summary:
  - Exit `0` when no issues.
  - Exit `3` when `-FailOnViolation` is set and issues exist (otherwise exit `0` with warnings).

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Paths` | string[] (required) | - | Files to lint. Supports pipeline input. |
| `MaxIterations` | int | `5` | Allowed iteration cap. |
| `IntervalSeconds` | double | `0` | Allowed loop interval. |
| `AllowedStrategies` | string[] | `Exact` | Permitted quantile strategies. |
| `FailOnViolation` | switch | Off | Exit `3` instead of `0` when violations exist. |

## Exit Codes
- `0` when no violations (or when `FailOnViolation` isn’t set).
- `3` when `-FailOnViolation` and violations exist.

## Related
- `tools/Invoke-CompareCli.ps1`
- `tools/hooks/scripts/pre-commit.ps1`
