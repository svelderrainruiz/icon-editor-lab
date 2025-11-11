# Watch-OrchestratedRest.ps1

**Path:** `tools/Watch-OrchestratedRest.ps1`

## Synopsis
Runs the orchestrated-run REST watcher (Node JS) to monitor GitHub Actions workflows and merges the summary into `session-index.json`.

## Description
- Ensures `dist/tools/watchers/orchestrated-watch.js` exists (invokes `npx tsc -p tsconfig.cli.json` when missing).
- Polls the GitHub Actions REST API for a specific run (`-RunId`) or the latest run on a branch (`-Branch` + `-Workflow`).
- Writes the watcher summary to `tests/results/_agent/watcher-rest.json` (override via `-OutPath`) and then calls `tools/Update-SessionIndexWatcher.ps1` so the data appears under `watchers.rest` in `session-index.json`.
- Tolerates transient API failures via `-PollMs`, `-ErrorGraceMs`, and `-NotFoundGraceMs`.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `RunId` | int | - | Workflow run id to follow. |
| `Branch` | string | - | Branch to watch when `RunId` isn’t provided. |
| `Workflow` | string | `.github/workflows/ci-orchestrated.yml` | Workflow file to filter branch runs. |
| `PollMs` | int | `15000` | Poll interval. |
| `ErrorGraceMs` | int | `120000` | Grace window for repeated API errors. |
| `NotFoundGraceMs` | int | `90000` | Grace window for 404 responses. |
| `OutPath` | string | `tests/results/_agent/watcher-rest.json` | Output summary path. |

## Exit Codes
- Mirrors the Node watcher exit code (0=success, non-zero when the watcher fails).

## Related
- `tools/Update-SessionIndexWatcher.ps1`
- `dist/tools/watchers/orchestrated-watch.js`
