# Check-TrackedBuildArtifacts.ps1

**Path:** `tools/Check-TrackedBuildArtifacts.ps1`

## Synopsis
Fails CI when `git ls-files` reveals build outputs (`src/**/obj`, `src/**/bin`, `**/TestResults`) that should remain untracked.

## Description
- Normalizes tracked paths to forward slashes, then checks them against a fixed set of globs that catch common .NET build folders and test-result directories.
- Supports allowlists in three forms (combined at runtime):
  - `-AllowPatterns` argument (PowerShell wildcards)
  - `ALLOWLIST_TRACKED_ARTIFACTS` environment variable (semicolon separated)
  - `-AllowListPath` file (one glob per line; defaults to `.ci/build-artifacts-allow.txt`)
- When offenders are found, each path is logged, and a Markdown snippet is appended to `GITHUB_STEP_SUMMARY` for PR visibility. Exits with code `3` so workflows can distinguish “gating failure” from script crashes.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `AllowPatterns` | string[] | *none* | Extra glob patterns to treat as allowed. |
| `AllowListPath` | string | `.ci/build-artifacts-allow.txt` | Optional file containing allowlisted globs (comments with `#` ignored). |

## Exit Codes
- `0` when no tracked build artifacts match.
- `3` when offenders are detected.
- Other values bubble up if `git ls-files` fails.

## Related
- `docs/LABVIEW_GATING.md`
