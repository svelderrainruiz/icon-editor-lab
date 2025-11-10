# Reset-IconEditorWorkspace.ps1

**Path:** `icon-editor-lab-8/tools/icon-editor/Reset-IconEditorWorkspace.ps1`  
**Hash:** `87db122ebe51`

## Synopsis
Requires -Version 7.0

## Description
—


### Parameters
| Name | Type | Default |
|---|---|---|
| `RepoRoot` | string |  |
| `IconEditorRoot` | string |  |
| `Versions` | int[] |  |
| `Bitness` | int[] |  |
| `LabVIEWProject` | string | 'lv_icon_editor' |
| `BuildSpec` | string | 'Editor Packed Library' |
| `SkipClose` | switch |  |


## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
