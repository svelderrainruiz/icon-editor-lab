# Watch-OrchestratedRest.ps1

**Path:** `icon-editor-lab-8/tools/Watch-OrchestratedRest.ps1`  
**Hash:** `8c2737f05216`

## Synopsis
Wrapper for the REST watcher that writes watcher-rest.json and merges it into session-index.json.

## Description
Invokes the compiled Node watcher (dist/tools/watchers/orchestrated-watch.js) with robust defaults


### Parameters
| Name | Type | Default |
|---|---|---|
| `RunId` | int |  |
| `Branch` | string |  |
| `Workflow` | string | '.github/workflows/ci-orchestrated.yml' |
| `PollMs` | int | 15000 |
| `ErrorGraceMs` | int | 120000 |
| `NotFoundGraceMs` | int | 90000 |
| `OutPath` | string | 'tests/results/_agent/watcher-rest.json' |


## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
