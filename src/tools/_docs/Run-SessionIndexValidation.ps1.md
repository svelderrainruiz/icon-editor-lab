# Run-SessionIndexValidation.ps1

**Path:** `tools/Run-SessionIndexValidation.ps1`

## Synopsis
Exercise the session-index flow end-to-end (Quick-Dispatcher smoke) and validate the produced `session-index.json` against the schema.

## Description
- Ensures `dist/tools/test-discovery.js` exists (runs `node tools/npm/run-script.mjs build` if necessary).
- Creates/cleans the `ResultsPath` directory (`tests/results/_validate-sessionindex` by default).
- Executes `tools/Quick-DispatcherSmoke.ps1 -PreferWorkspace`, which generates a representative `session-index.json`.
- Verifies `session-index.json` exists and validates it via `tools/Invoke-JsonSchemaLite.ps1` using the provided schema (default `docs/schemas/session-index-v1.schema.json`).
- Useful for CI checks that ensure schema compliance after schema/report changes.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `ResultsPath` | string | `tests/results/_validate-sessionindex` | Directory where smoke artifacts are written. |
| `SchemaPath` | string | `docs/schemas/session-index-v1.schema.json` | JSON schema used by `Invoke-JsonSchemaLite`. |

## Exit Codes
- `0` — Smoke + schema validation succeeded.
- `2` — Build artifacts missing or `session-index.json` not found.
- Other non-zero values bubble up from the smoke/schema scripts.

## Related
- `tools/Quick-DispatcherSmoke.ps1`
- `tools/Invoke-JsonSchemaLite.ps1`
- `tools/Ensure-SessionIndex.ps1`
