# Invoke-LabelsSync.ps1

**Path:** `tools/Invoke-LabelsSync.ps1`

## Synopsis
Compares `.github/labels.yml` with the repository’s actual GitHub labels and optionally enforces parity using the REST API.

## Description
- Parses `.github/labels.yml`, extracts label names, and (when a token is available) calls `GET /repos/{owner}/{repo}/labels` to identify missing labels.
- Modes:
  - Summary (default) – prints counts and lists missing labels without failing.
  - `-Enforce` (or `-Auto` when `GITHUB_TOKEN` is set) – exits with code 2 when labels are missing.
- When tokens are absent, the script degrades gracefully with notices.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Enforce` | switch | Off | Requires `GITHUB_TOKEN`; fails if labels are missing. |
| `Auto` | switch | Off | Behaves like `-Enforce` only when a token is present. |

## Exit Codes
- `0` when labels are in sync or running in summary mode.
- `2` when enforcement is enabled and labels are missing or API calls fail.

## Related
- `.github/labels.yml`
- GitHub Actions label sync automation
