# Write-ArtifactList.ps1

**Path:** `tools/Write-ArtifactList.ps1`

## Synopsis
Append a simple bullet list of artifact paths to `GITHUB_STEP_SUMMARY`, verifying existence before listing.

## Description
- Accepts `-Paths` (string array) and optional `-Title` (defaults to “Artifacts”).
- Skips work entirely when `GITHUB_STEP_SUMMARY` is unset—so local runs do not fail.
- Prints “(none found)” when no valid paths exist; otherwise each line is `- <path>`.
- Uses `Test-Path` to ensure only existing files/dirs are listed.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Paths` | string[] (required) | — | Files/directories to check before listing. |
| `Title` | string | `Artifacts` | Markdown heading such as “### Build Outputs”. |

## Outputs
- Markdown appended to `GITHUB_STEP_SUMMARY`.

## Related
- `tools/Write-ArtifactMap.ps1`
