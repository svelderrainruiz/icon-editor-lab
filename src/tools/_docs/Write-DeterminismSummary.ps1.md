# Write-DeterminismSummary.ps1

**Path:** `tools/Write-DeterminismSummary.ps1`

## Synopsis
Append a quick determinism profile summary (loop settings, quantile strategy, adaptive flags) to the GitHub step summary using environment variables.

## Description
- Reads `LVCI_DETERMINISTIC` plus the `LOOP_*` env vars (max iterations, interval, quantile, histogram bins, reconcile, adaptive).
- When `GITHUB_STEP_SUMMARY` is available, emits a markdown block:
  ```
  ### Determinism
  - Profile: deterministic
  - Iterations: 10
  ...
  ```
- Silently exits (code 0) when the step summary file is missing to avoid failing local runs.
- Logs a notice instead of throwing if something goes wrong, keeping CI resilient.

## Outputs
- Markdown appended to `GITHUB_STEP_SUMMARY`.

## Related
- `docs/LABVIEW_GATING.md` (determinism requirements)
