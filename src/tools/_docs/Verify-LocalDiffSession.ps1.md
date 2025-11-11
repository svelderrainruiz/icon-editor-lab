# Verify-LocalDiffSession.ps1

**Path:** `tools/Verify-LocalDiffSession.ps1`

## Synopsis
Run a local LVCompare session against the provided base/head VIs, exercising sentinel/CLI guardrails and producing a JSON summary for troubleshooting.

## Description
- Accepts absolute VI paths (`-BaseVi`, `-HeadVi`) and orchestrates one or two CompareVI runs depending on `-Mode`:
  - `normal` (default) – single compare run.
  - `cli-suppressed` – bypass LVCompare CLI spawning.
  - `git-context` – simulates git-aware output.
  - `duplicate-window` – runs twice to validate sentinel behavior.
- Resolves LabVIEW/LVCompare config from `configs/labview-paths*.json`. When `-AutoConfig` is set, invokes `tools/New-LVCompareConfig.ps1` to regenerate missing configs before retrying.
- `-ProbeSetup` skips compare runs and only verifies configuration.
- `-UseStub` forces a stub CompareVI invocation (useful on hosts without LabVIEW).
- `-RenderReport` saves HTML compare reports in the run directories; `-NoiseProfile` chooses the ignore bundle (`full` or `legacy`).
- Maintains CLI sentinel files (`COMPAREVI_CLI_SENTINEL_TTL`, etc.) to ensure duplicate-window scenarios behave like production.
- Writes `local-diff-summary.json` in `-ResultsRoot` (default `tests/results/_agent/local-diff`) capturing run metadata, skip reasons, exit codes, and setup status.
- When `-Stateless` is set, removes `configs/labview-paths.local.json` after completion so subsequent runs start fresh.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `BaseVi` | string (required) | — | Absolute path to the “base” VI. |
| `HeadVi` | string (required) | — | Absolute path to the “head” VI. |
| `Mode` | string (`normal`,`cli-suppressed`,`git-context`,`duplicate-window`) | `normal` | Controls compare strategy. |
| `SentinelTtlSeconds` | int | `60` | TTL applied during duplicate-window runs. |
| `RenderReport` | switch | Off | Produce an HTML compare report per run. |
| `UseStub` | switch | Off | Use stub compare harness (no LabVIEW). |
| `ProbeSetup` | switch | Off | Verify configuration only; skip compare. |
| `AutoConfig` | switch | Off | Invoke `New-LVCompareConfig.ps1` when config missing. |
| `Stateless` | switch | Off | Delete `labview-paths.local.json` after completion. |
| `LabVIEWVersion` | string | — | Override version used for configuration. |
| `LabVIEWBitness` | string (`32`,`64`) | — | Override bitness. |
| `NoiseProfile` | string (`full`,`legacy`) | `full` | Selects LVCompare ignore bundle. |
| `ResultsRoot` | string | `tests/results/_agent/local-diff` | Directory for run folders + summary JSON. |

## Outputs
- Run directories under `<ResultsRoot>` (`run-01`, `run-02`, etc.) containing CompareVI output.
- `<ResultsRoot>/local-diff-summary.json` with schema-free run metadata and setup status.
- Returns a `[pscustomobject]` describing `resultsDir`, `summary`, `runs`, and `setupStatus`.

## Exit Codes
- `0` — Compare runs completed (or probe succeeded).
- `1` — LVCompare setup missing/invalid (summary still written with guidance).
- `>1` — Compare harness or CLI sentinel errors bubbled up.

## Related
- `tools/Verify-LVCompareSetup.ps1`
- `tools/New-LVCompareConfig.ps1`
