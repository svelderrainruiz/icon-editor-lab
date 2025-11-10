# Guard-LabVIEWPersistence.ps1

**Path:** `icon-editor-lab-8/tools/Guard-LabVIEWPersistence.ps1`  
**Hash:** `88b80ae0fbea`

## Synopsis
Guard to observe LabVIEW/LVCompare process presence around phases.

## Description
Samples pwsh process list for LabVIEW.exe and LVCompare.exe, writes/updates


### Parameters
| Name | Type | Default |
|---|---|---|
| `ResultsDir` | string | 'results/fixture-drift' |


## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
