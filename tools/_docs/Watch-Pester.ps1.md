# Watch-Pester.ps1

**Path:** `icon-editor-lab-8/tools/Watch-Pester.ps1`  
**Hash:** `27c065d7797b`

## Synopsis
Lightweight session naming for observability

## Description
—


### Parameters
| Name | Type | Default |
|---|---|---|
| `Path` | string | '.' |
| `Filter` | string | '*.ps1' |
| `DebounceMilliseconds` | int | 400 |
| `RunAllOnStart` | switch |  |
| `NoSummary` | switch |  |
| `TestPath` | string | 'tests' |
| `Tag` | string |  |
| `ExcludeTag` | string |  |
| `Quiet` | switch |  |
| `SingleRun` | switch |  |
| `ChangedOnly` | switch |  |
| `BeepOnFail` | switch |  |
| `InferTestsFromSource` | switch |  |
| `DeltaJsonPath` | string |  |
| `DeltaHistoryPath` | string |  |
| `MappingConfig` | string |  |
| `ShowFailed` | switch |  |
| `MaxFailedList` | int | 10 |
| `OnlyFailed` | switch |  |
| `NotifyScript` | string |  |


## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
