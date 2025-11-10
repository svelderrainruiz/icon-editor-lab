# New-SampleId.ps1

**Path:** `tools/New-SampleId.ps1`

## Synopsis
Generates a human-readable sample ID (used by workflow_dispatch runs and artifact folders) with an optional prefix.

## Description
- Format: `<prefix>ts-YYYYMMDD-HHMMSS-XXXX`, where `XXXX` is a random alphanumeric suffix.
- Prints the ID to stdout so GitHub Actions can capture it via `$(pwsh ... )` or `GITHUB_OUTPUT`.
- Keeps IDs short yet unique enough for manual triage.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Prefix` | string | empty | Prepended verbatim (e.g., `icon-editor-`). |

## Outputs
- Sample ID string written to stdout.

## Related
- `.github/workflows/*.yml`
