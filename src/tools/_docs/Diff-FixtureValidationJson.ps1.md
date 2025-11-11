# Diff-FixtureValidationJson.ps1

**Path:** `tools/Diff-FixtureValidationJson.ps1`

## Synopsis
Compares two `fixture-validation.json` files and emits a delta JSON, optionally failing when new structural issues appear.

## Description
- Accepts `-Baseline` and `-Current` fixture-validation outputs (from `Validate-Fixtures.ps1 -Json`), computes per-category deltas (missing, untracked, hashMismatch, etc.), and lists newly introduced structural issues.
- Supports schema v1 and v2 outputs; `-UseV2Schema` or `DELTA_SCHEMA_VERSION=v2` switches the emitted schema to `fixture-validation-delta-v2`.
- `-FailOnNewStructuralIssue` causes the script to exit `3` when new structural issue types (e.g., missing/untracked) are introduced, reinforcing ISO gating.
- When `-Output` is omitted, the delta JSON is written to stdout; otherwise it’s saved to the specified path.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Baseline` | string (required) | - | Path to the previous `fixture-validation.json`. |
| `Current` | string (required) | - | Path to the latest `fixture-validation.json`. |
| `Output` | string | *stdout* | Destination for the delta JSON. |
| `FailOnNewStructuralIssue` | switch | Off | Exit `3` when new structural categories appear. |
| `UseV2Schema` | switch | Off | Emit `fixture-validation-delta-v2` schema. |

## Exit Codes
- `0` success (even if deltas exist).
- `2` when files are missing or invalid JSON.
- `3` when `-FailOnNewStructuralIssue` is set and new structural issues are detected.

## Related
- `tools/Validate-Fixtures.ps1`
- `docs/LABVIEW_GATING.md`
