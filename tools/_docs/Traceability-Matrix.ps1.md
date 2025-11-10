# Traceability-Matrix.ps1

**Path:** `icon-editor-lab-8/tools/Traceability-Matrix.ps1`  
**Hash:** `5e170c518953`

## Synopsis
Traceability Matrix Builder (Traceability Matrix Plan v1.0.0)

## Description
—


### Parameters
| Name | Type | Default |
|---|---|---|
| `TestsPath` | string | 'tests' |
| `ResultsRoot` | string | 'tests/results' |
| `OutDir` | string |  |
| `IncludePatterns` | string[] |  |
| `RunId` | string |  |
| `Seed` | string |  |
| `RenderHtml` | switch |  |


## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
