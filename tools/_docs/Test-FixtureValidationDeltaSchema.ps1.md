# Test-FixtureValidationDeltaSchema.ps1

**Path:** `tools/Test-FixtureValidationDeltaSchema.ps1`

## Synopsis
Sanity-check a fixture-validation delta JSON file (schema, required fields, and array shapes) without needing an external JSON Schema engine.

## Description
- Accepts the delta artifact produced by `Validate-Fixtures.ps1` and verifies it declares `schema=fixture-validation-delta-v1` as well as the standard keys (`baselinePath`, `currentPath`, `deltaCounts`, etc.).
- Ensures `changes` and `newStructuralIssues` are arrays and each change entry contains `category`, `baseline`, `current`, and `delta` blocks.
- Optional `-SchemaPath` exists for parity with older workflows, but the script currently performs inline checks rather than invoking a schema library.
- Exits with descriptive errors so CI jobs can distinguish malformed artifacts (exit 2) from structural regressions (exit 3).

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `DeltaJsonPath` | string (required) | — | Path to the delta JSON produced by fixture validation. |
| `SchemaPath` | string | `docs/schemas/fixture-validation-delta-v1.schema.json` | Only used for existence checking today. |

## Outputs
- Console message (`Delta schema basic validation passed.`) when all checks succeed.

## Exit Codes
- `0` — Delta file satisfied all assertions.
- `2` — Input JSON or schema file missing/unreadable.
- `3` — Schema version mismatch or required fields missing.

## Related
- `tools/Validate-Fixtures.ps1`
- `docs/ICON_EDITOR_LAB_MIGRATION.md` (fixture quality gates)
