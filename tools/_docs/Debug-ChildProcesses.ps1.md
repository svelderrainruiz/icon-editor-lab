# Debug-ChildProcesses.ps1

**Path:** `icon-editor-lab-8/tools/Debug-ChildProcesses.ps1`  
**Hash:** `bf85ae488eba`

## Synopsis
Capture a snapshot of child processes (pwsh, conhost, LabVIEW, LVCompare) with memory usage.

## Description
Writes a JSON snapshot to tests/results/_agent/child-procs.json and optionally appends


### Parameters
| Name | Type | Default |
|---|---|---|
| `ResultsDir` | string | 'tests/results' |
| `Names` | string[] | @('pwsh' |


## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
