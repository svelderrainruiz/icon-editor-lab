# Collect-RunnerHealth.ps1

**Path:** `icon-editor-lab-8/tools/Collect-RunnerHealth.ps1`  
**Hash:** `521d8813437a`

## Synopsis
Service probe (Windows and Linux)

## Description
—


### Parameters
| Name | Type | Default |
|---|---|---|
| `Enterprise` | string | '' |
| `Repo` | string |  |
| `ServiceName` | string | 'actions.runner.enterprises-labview-community-ci-cd.research' |
| `ResultsDir` | string | 'tests/results' |
| `AppendSummary` | switch |  |
| `EmitJson` | switch |  |
| `IncludeGhApi` | switch |  |


## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
