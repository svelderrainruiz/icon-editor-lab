# Prepare-VipViDiffRequests.ps1

**Path:** `tools/icon-editor/Prepare-VipViDiffRequests.ps1`

## Synopsis
Scans extracted VIP artifacts for VI files and generates `vi-diff-requests@v1` entries so LVCompare can diff VIP output versus the repo sources.

## Description
- Requires `-ExtractRoot`, the directory where VIP contents were unpacked. Uses the canonical `"National Instruments\LabVIEW Icon Editor\"` marker to determine the relative path inside the VIP.
- For each VI found, copies the VIP version into `<OutputDir>/head/<relative path>`, notes whether a matching file exists in `vendor/labview-icon-editor/...`, and writes a compare request (base/head absolute paths, category label, relative path).
- Produces a summary JSON (`vi-diff-requests.json` by default) that downstream compare workflows can ingest; also returns metadata (head root, source root, count).

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `ExtractRoot` | string (required) | - | VIP extraction folder to scan. |
| `RepoRoot` | string | repo root | Root of the icon-editor sources. |
| `SourceRoot` | string | `vendor/labview-icon-editor` | Relative path to baseline sources. |
| `OutputDir` | string | `<ExtractRoot>/../vip-vi-diff` | Destination for head copies + requests JSON. |
| `RequestsPath` | string | `<OutputDir>/vi-diff-requests.json` | Override to place JSON elsewhere. |
| `Category` | string | `vip` | Category tag stored in each request. |

## Outputs
- JSON file following `icon-editor/vi-diff-requests@v1`, plus a returned PSCustomObject describing the request path and head directory.

## Related
- `tools/icon-editor/Prepare-FixtureViDiffs.ps1`
- `tools/Run-HeadlessCompare.ps1`

