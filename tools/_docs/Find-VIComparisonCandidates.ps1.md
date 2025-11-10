# Find-VIComparisonCandidates.ps1

**Path:** `icon-editor-lab-8/tools/compare/Find-VIComparisonCandidates.ps1`  
**Hash:** `9a580b2e083f`

## Synopsis
Requires -Version 7.0

## Description
—


### Parameters
| Name | Type | Default |
|---|---|---|
| `RepoPath` | string |  |
| `BaseRef` | string |  |
| `HeadRef` | string | 'HEAD' |
| `MaxCommits` | int | 50 |
| `Kinds` | string[] | @('vi' |


## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
