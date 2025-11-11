# Analyze-JobLog.ps1

**Path:** `tools/Analyze-JobLog.ps1`

## Synopsis
Normalizes a GitHub Actions job log (either zipped steps or raw text) and optionally searches it with a regex so regressions can be diagnosed locally.

## Description
- Accepts the artifact produced by `gh api repos/.../actions/jobs/<id>/logs` which can be either a `.zip` bundle of per-step logs or a single UTF‑8 text file.
- Detects zip files by signature, stitches the entries together in lexical order, strips ANSI escape sequences, and returns the unified string.
- When `-Pattern` is supplied, the script runs the regex against the sanitized content and returns the matches alongside the log text for further parsing.
- Designed for ISO traceability on failure analysis: pair the output with the scenario log referenced in `docs/LABVIEW_GATING.md`.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `LogPath` | string (required) | - | Path to the downloaded `.zip` or `.txt` job log. |
| `Pattern` | string | *none* | Optional .NET regex used to locate failures (e.g., `(?s)##\\[error].+`). |

## Outputs
- `[pscustomobject]` with `Content` (UTF-8 text) and `Matches` (regex matches or `$null`).
- Removes ANSI codes so downstream tooling does not double-escape sequences.

## Exit Codes
- `0` when the log is read successfully.
- Non-zero if the file is missing, unreadable, or the archive is corrupt.

## Related
- `docs/LABVIEW_GATING.md`
