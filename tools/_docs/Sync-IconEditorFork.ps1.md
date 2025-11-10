# Sync-IconEditorFork.ps1

**Path:** `icon-editor-lab-8/tools/icon-editor/Sync-IconEditorFork.ps1`  
**Hash:** `c30fb57af8fd`

## Synopsis
Requires -Version 7.0

## Description
—


### Parameters
| Name | Type | Default |
|---|---|---|
| `RemoteName` | string | 'icon-editor' |
| `RepoSlug` | string |  |
| `Branch` | string | 'develop' |
| `WorkingPath` | string |  |
| `UpdateFixture` | switch |  |
| `RunValidateLocal` | switch |  |
| `SkipBootstrap` | switch |  |


## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
