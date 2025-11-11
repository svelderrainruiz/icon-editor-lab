# Invoke-ValidateLocal.ps1

**Path:** `tools/icon-editor/Invoke-ValidateLocal.ps1`

## Synopsis
Runs the icon-editor “Validate” workflow locally: bootstrap priority hooks, stage fixtures, run VI diffs/LVCompare/TestStand checks, and write results under `_agent/icon-editor/local-validate`.

## Description
- Performs optional bootstrap (`tools/priority/bootstrap.ps1`) unless `-SkipBootstrap` is set, then runs hook parity checks (unless `-DryRun`).
- Resolves current/baseline fixtures and manifests, prepares resource overlays, and orchestrates:
  - Fixture describe + validate steps.
  - VI diff prep/run (with optional `-SkipLVCompare` or `-IncludeSimulation` for dry-run compare).
  - Tests and summary report generation.
- Results are written to `tests/results/_agent/icon-editor/local-validate` (override with `-ResultsRoot`); intermediate workspaces can be preserved via `-KeepWorkspace`.

### Parameters (subset)
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `FixturePath` | string (required) | - | VIP artifact produced by the build. |
| `BaselineFixture` / `BaselineManifest` | string | - | Optional baselines for diffing. |
| `ResourceOverlayRoot` | string | vendor default | Override overlay location. |
| `SkipLVCompare` | switch | Off | Run compare steps in dry-run mode. |
| `ResultsRoot` | string | `tests/results/_agent/icon-editor/local-validate` | Destination for artifacts. |
| `KeepWorkspace` | switch | Off | Preserve work directories. |
| `SkipBootstrap` | switch | Off | Assume priority/bootstrap already ran. |
| `IncludeSimulation` | switch | Off | Include Simulate-IconEditorBuild diff passes. |
| `DryRun` | switch | Off | Skip destructive actions (hooks, LVCompare). |

## Outputs
- Reports and artifacts under `<ResultsRoot>` mirroring CI’s Validate workflow (fixture summaries, VI diff captures, test summaries).

## Exit Codes
- Non-zero when any stage fails (bootstrap, describe, diffs, tests, etc.).

## Related
- `tools/icon-editor/Stage-IconEditorSnapshot.ps1`
- `docs/ICON_EDITOR_LAB_MIGRATION.md`
