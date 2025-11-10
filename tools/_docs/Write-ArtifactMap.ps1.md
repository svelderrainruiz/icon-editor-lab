# Write-ArtifactMap.ps1

**Path:** `tools/Write-ArtifactMap.ps1`

## Synopsis
Produce a richer artifact summary (sizes, timestamps, counts) and append it to `GITHUB_STEP_SUMMARY`.

## Description
- Accepts either `-Paths` (array) or `-PathsList` (whitespace/semicolon-delimited string) to accommodate workflow inputs.
- For each path:
  - Existing file → `- path (12.3 MB, 2025-02-12 18:03:10)`
  - Existing directory → counts files recursively and prints total size.
  - Missing path → flagged as `(missing)`.
- Uses a helper `Fmt-Size` to format bytes into B/KB/MB for readability.
- No-op when `GITHUB_STEP_SUMMARY` is absent.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Paths` | string[] | — | Explicit list of artifact paths. |
| `PathsList` | string | — | Alternative semicolon/space separated list. |
| `Title` | string | `Artifacts Map` | Markdown heading text. |

## Outputs
- Markdown appended to `GITHUB_STEP_SUMMARY` describing artifact stats.

## Related
- `tools/Write-ArtifactList.ps1`
