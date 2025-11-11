# Invoke-JsonSchemaLite.ps1

**Path:** `tools/Invoke-JsonSchemaLite.ps1`

## Synopsis
Validates a JSON file against a “schema-lite” definition (custom JSON schema subset) with automatic schema fallback when the payload’s `schema` id disagrees.

## Description
- Accepts `-JsonPath` and `-SchemaPath`; loads both as JSON and performs structural checks (types, required fields, enum/const values).
- If the schema’s `const` doesn’t match the payload’s `schema` field, the script looks for a sibling `<schema>.schema.json` file matching the payload id and uses it automatically (handles schema migrations).
- Emits descriptive errors to stderr and exits `2` for parse/validation failures; returns `0` on success.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `JsonPath` | string (required) | - | Target JSON file to validate. |
| `SchemaPath` | string (required) | - | Schema-lite JSON file. |

## Exit Codes
- `0` when validation succeeds.
- `2` for parse errors or validation failures.

## Related
- `tools/Validate-Fixtures.ps1`
- `docs/schemas/`
