# Watch-RunAndTrack.ps1

**Path:** `icon-editor-lab-8/tools/Watch-RunAndTrack.ps1`  
**Hash:** `ba74439fdb56`

## Synopsis
Dispatch a GitHub workflow and monitor its jobs until completion.

## Description
Wraps `gh workflow run` and `tools/Track-WorkflowRun.ps1`. The script:


### Parameters
| Name | Type | Default |
|---|---|---|
| `Workflow` | string | 'validate.yml' |
| `Ref` | string |  |
| `Repo` | string |  |
| `PollSeconds` | int | 10 |
| `MonitorPollSeconds` | int | 20 |
| `TimeoutSeconds` | int | 300 |
| `OutputPath` | string |  |
| `Quiet` | switch |  |
| `TrackQuiet` | switch |  |
| `DisableCheckRuns` | switch |  |


## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
