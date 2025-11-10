# Replay-ApplyVipcJob.ps1

**Path:** `tools/icon-editor/Replay-ApplyVipcJob.ps1`

## Synopsis
Replays the “Apply VIPC Dependencies” GitHub job locally by downloading its logs, resolving the LabVIEW version/bitness, and calling the same `ApplyVIPC.ps1` script that CI uses.

## Description
- Takes either a workflow `RunId`/`JobName` (downloads logs via `gh api`) or a local `LogPath`, parses the log to determine LabVIEW version/bitness and VIPM settings, then replays the job inside your workspace.
- Calls `.github/actions/apply-vipc/ApplyVIPC.ps1` with the resolved parameters (`-MinimumSupportedLVVersion`, `-VIP_LVVersion`, `-SupportedBitness`, `-Toolchain`) so you can reproduce CI behaviour on your machine.
- `-SkipExecution` prints the command without running it; `-Toolchain` lets you switch between `vipm` and `gcli`.

### Parameters (subset)
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `RunId` | string | - | Workflow run ID to fetch logs from. |
| `JobName` | string | `Apply VIPC Dependencies (2026, 64)` |
| `Repository` | string | current repo | Needed when replaying runs from forks. |
| `LogPath` | string | - | Use an existing log instead of downloading. |
| `Workspace` | string | current dir | Mirrors `${{ github.workspace }}`. |
| `VipcPath` | string | `.github/actions/apply-vipc/runner_dependencies.vipc` |
| `MinimumSupportedLVVersion` / `VipLabVIEWVersion` | string | auto | Override detection. |
| `SupportedBitness` | int | auto | Override detection. |
| `Toolchain` | string (`vipm`,`gcli`) | `vipm` |
| `SkipExecution` | switch | Off | Print the replay command only. |

## Outputs
- Console log showing resolved parameters and the replay command; replayed job runs `ApplyVIPC.ps1` inside your workspace.

## Related
- `.github/actions/apply-vipc/ApplyVIPC.ps1`
- `tools/icon-editor/Replay-BuildVipJob.ps1`
