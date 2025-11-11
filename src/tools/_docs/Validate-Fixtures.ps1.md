# Validate-Fixtures.ps1

**Path:** `tools/Validate-Fixtures.ps1`

## Synopsis
Validates canonical fixture artifacts by checking file existence, size thresholds, Git tracking status, and hashes recorded in `fixtures.manifest.json`, optionally emitting structured JSON.

## Description
- Performs two phases: basic file checks (missing/untracked/too small) and manifest validation (hash/size comparisons, duplicate entries, schema issues). Exit codes communicate the first failure class (missing=2, untracked=3, size issues=4, hash mismatch=6, structural errors=7, duplicates=8, multiple issues=5).
- Can emit JSON (`-Json`) instead of console output, making it easier for downstream scripts to parse.
- Supports test/debug flags:
  - `-TestAllowFixtureUpdate` (internal) downgrades hash mismatches.
  - `-DisableToken` bypasses the usual commit token requirement.
  - `-RequirePair`/`-FailOnExpectedMismatch` enforce pair validations.
  - `-ManifestPath`, `-EvidencePath`, `-MinBytes`, `-QuietOutput` customize behavior.

## Parameters (subset)
| Name | Type | Notes |
| --- | --- | --- |
| `Json` | switch | Output JSON object instead of human-readable lines. |
| `MinBytes` | int | Minimum allowed file size before flagging `tooSmall`. |
| `ManifestPath` | string | Custom manifest path; defaults to `fixtures.manifest.json`. |
| `TestAllowFixtureUpdate` / `DisableToken` | switch | Internal/testing options. |
| `RequirePair` / `FailOnExpectedMismatch` | switch | Enforce paired validations. |

## Outputs
- Console lines or JSON summary describing issues; exit codes indicate severity.

## Related
- `tools/Run-FixtureValidation.ps1`
- `tools/Diff-FixtureValidationJson.ps1`
