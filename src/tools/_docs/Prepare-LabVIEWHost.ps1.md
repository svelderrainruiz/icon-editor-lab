# Prepare-LabVIEWHost.ps1

**Path:** `tools/icon-editor/Prepare-LabVIEWHost.ps1`

## Synopsis
End-to-end host-prep orchestrator that stages icon-editor fixtures, enables dev mode, resets workspaces, detects rogue LabVIEW processes, and emits host-prep reports.

## Description
- Takes a fixture package (`-FixturePath`) and optional LabVIEW versions/bitness matrix; stages snapshots via `Stage-IconEditorSnapshot`, enables dev mode, applies VIPCs, runs rogue detection, and resets workspaces unless skip flags disable a step.
- Wraps every critical step with closure checks (`Close-LabVIEW.ps1`) to ensure no LabVIEW.exe processes remain; records telemetry (JSON + Markdown via `Write-HostPrepReport`) under `tests/results/_agent/icon-editor`.
- Supports dry-run mode, custom workspace roots, StageName overrides, and log path forwarding (honors `INVOCATION_LOG_PATH` when set).

### Parameters (subset)
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `FixturePath` | string (required) | - | Path to the icon-editor fixture bundle to validate. |
| `Versions` | object[] | `@(2021)` | LabVIEW versions to prep. |
| `Bitness` | object[] | `@(32,64)` | Bitness per version. |
| `StageName` | string | auto | Label used for results/reporting. |
| `WorkspaceRoot` | string | `tests/results/_agent/icon-editor/host-prep` | Where snapshots/telemetry are written. |
| `Operation` | string | `MissingInProject` | Telemetry label for dev-mode steps. |
| `SkipStage`, `SkipDevMode`, `SkipClose`, `SkipReset`, `SkipRogueDetection`, `SkipPostRogueDetection`, `DryRun` | switch | Off | Skip individual steps or perform a dry run. |

## Outputs
- Host-prep summary JSON plus Markdown reports (see `tests/results/_agent/icon-editor/host-prep`). Warnings are recorded when forced terminations occur.

## Related
- `tools/icon-editor/Describe-IconEditorFixture.ps1`
- `tools/icon-editor/Invoke-LabVIEWHostPrep.ps1`
- `docs/LABVIEW_GATING.md`
