# Run-FixtureValidation.ps1

**Path:** `tools/Run-FixtureValidation.ps1`

## Synopsis
Drives the fixture validation workflow (snapshot ➜ delta ➜ summary) by chaining `Validate-Fixtures`, schema checks, delta comparison, and summary writers.

## Description
- Runs `tools/Validate-Fixtures.ps1 -Json` to create `fixture-validation.json`, validates it against the fixture schema, and, when a previous snapshot exists (`fixture-validation-prev.json`), invokes `Diff-FixtureValidationJson.ps1` and `Test-FixtureValidationDeltaSchema.ps1` to produce `fixture-validation-delta.json`.
- Generates a Markdown summary via `Write-FixtureValidationSummary.ps1` and refreshes the `fixture-validation-prev.json` baseline.
- `-NoticeOnly` downgrades structural issues to warnings (exit 0) for local runs; CI should omit the flag so structural regressions fail the job.

### Parameters
| Name | Type | Default |
| --- | --- | --- |
| `NoticeOnly` | switch | Off |

## Outputs
- `fixture-validation.json`, `fixture-validation-delta.json` (when baseline exists), `fixture-summary.md`, and updated `fixture-validation-prev.json`.

## Related
- `tools/Validate-Fixtures.ps1`
- `tools/Diff-FixtureValidationJson.ps1`
- `docs/ICON_EDITOR_LAB_MIGRATION.md`
