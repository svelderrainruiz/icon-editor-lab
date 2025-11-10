# Update-SessionIndexBranchProtection.ps1

**Path:** `icon-editor-lab-8/tools/Update-SessionIndexBranchProtection.ps1`  
**Hash:** `04184b857661`

## Synopsis
Inject branch-protection verification metadata into a session-index.json file.

## Description
Reads a canonical branch→status mapping, computes its digest, compares the expected


### Parameters
| Name | Type | Default |
|---|---|---|
| `ResultsDir` | string | 'tests/results' |
| `PolicyPath` | string | 'tools/policy/branch-required-checks.json' |
| `ProducedContexts` | string[] |  |
| `Branch` | string | $env:GITHUB_REF_NAME |
| `Strict` | switch |  |
| `ActualContexts` | string[] |  |


## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
