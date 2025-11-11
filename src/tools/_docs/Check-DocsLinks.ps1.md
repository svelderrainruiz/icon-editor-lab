# Check-DocsLinks.ps1

**Path:** `tools/Check-DocsLinks.ps1`

## Synopsis
Scans Markdown files for broken intra-repo references and, when requested, HEAD-checks external links so wiki/ISO docs stay healthy.

## Description
- Recurses from `-Path` (repo root by default), ignoring `.git`, `vendor`, `node_modules`, build folders, and any custom `-Ignore` globs.
- Uses a lightweight regex (`[label](target)`) to find links:
  - Relative links are resolved against the file's directory; missing targets are collected unless explicitly allow-listed.
  - `http/https` links are optionally validated with HEAD requests when `-External` or `-Http` is provided. Failures capture the HTTP status or `ERR`.
- Emits a summary to stdout plus, if `GITHUB_STEP_SUMMARY` is set, a Markdown report showing the first few offenders.
- Optional `-OutputJson` writes `docs-links/v1` telemetry with local vs HTTP errors so CI artifacts can be archived.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Path` | string | `.` | Root directory to scan. |
| `External` / `Http` | switch | Off | Enable HTTP HEAD checks for external links. |
| `HttpTimeoutSec` | int | `5` | Timeout for each HEAD request (accepts string/int inputs). |
| `Ignore` | string[] | *none* | Additional glob patterns to skip. |
| `AllowListPath` | string | `.ci/link-allowlist.txt` | File containing link patterns to ignore. |
| `OutputJson` | string | - | When set, writes the JSON report to this path. |
| `Quiet` | switch | Off | Suppresses info logs while retaining error summaries. |

## Exit Codes
- `0` when all checked links are valid.
- `2` when any local or HTTP link fails validation.

## Related
- `docs/LABVIEW_GATING.md`
