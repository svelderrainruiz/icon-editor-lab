# Invoke-VipmCliBuild.ps1

**Path:** `icon-editor-lab-8/tools/icon-editor/Invoke-VipmCliBuild.ps1`  
**Hash:** `076f358bfa21`

## Synopsis
Requires -Version 7.0

## Description
—


### Parameters
| Name | Type | Default |
|---|---|---|
| `RepoRoot` | string |  |
| `IconEditorRoot` | string |  |
| `RepoSlug` | string | 'LabVIEW-Community-CI-CD/labview-icon-editor' |
| `MinimumSupportedLVVersion` | int | 2023 |
| `PackageMinimumSupportedLVVersion` | int | 2026 |
| `PackageSupportedBitness` | int | 64 |
| `SkipSync` | switch |  |
| `SkipVipcApply` | switch |  |
| `SkipBuild` | switch |  |
| `SkipRogueCheck` | switch |  |
| `SkipClose` | switch |  |
| `Major` | int | 1 |
| `Minor` | int | 4 |
| `Patch` | int | 1 |
| `Build` | int |  |
| `ResultsRoot` | string |  |
| `VerboseOutput` | switch |  |


## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
