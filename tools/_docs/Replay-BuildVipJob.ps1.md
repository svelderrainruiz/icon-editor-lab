# Replay-BuildVipJob.ps1

**Path:** `tools/icon-editor/Replay-BuildVipJob.ps1`

## Synopsis
Replays the “Build VI Package” GitHub Actions job locally, including release-note regeneration, VIPB display-info updates, artifact downloads, and the VIPM/g-cli build step.

## Description
- Accepts a workflow `RunId` (downloads logs via `gh`) or a local `LogPath`. Parses the job log to recover the display-info payload, LabVIEW versions, bitness, and VIPB metadata.
- Recreates the job sequence: regenerate release notes (unless `-SkipReleaseNotes`), run `Update-VipbDisplayInfo.ps1`, run `build_vip.ps1` via the chosen toolchain (`-BuildToolchain gcli|vipm`), optionally close LabVIEW and download artifacts.
- `-DownloadArtifacts` pulls the run’s artifacts to populate resource/plugins with the latest lvlibp files before replaying.

### Parameters (subset)
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `RunId` | string | - | Workflow run to replay; otherwise supply `LogPath`. |
| `LogPath` | string | - | Use an existing job log. |
| `JobName` | string | `Build VI Package` |
| `Workspace` | string | current dir | Maps to `${{ github.workspace }}`. |
| `ReleaseNotesPath` | string | `Tooling/deployment/release_notes.md` |
| `SkipReleaseNotes`, `SkipVipbUpdate`, `SkipBuild` | switch | Skip individual phases. |
| `CloseLabVIEW` | switch | Calls `.github/actions/close-labview/Close_LabVIEW.ps1` after replay. |
| `DownloadArtifacts` | switch | Download run artifacts before replaying. |
| `BuildToolchain` | string (`gcli`,`vipm`) | `gcli` |
| `BuildProvider` | string | Provider name forwarded to the chosen toolchain. |

## Outputs
- Console output showing resolved metadata and each replayed phase; reruns the VIP build scripts inside your workspace.

## Related
- `.github/actions/build-vip/BuildVip.ps1`
- `tools/icon-editor/Replay-ApplyVipcJob.ps1`
