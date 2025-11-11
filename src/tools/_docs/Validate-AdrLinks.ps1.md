# Validate-AdrLinks.ps1

**Path:** `tools/Validate-AdrLinks.ps1`

## Synopsis
Checks that every requirement doc (`docs/requirements/**/*.md`) references existing ADRs under `docs/adr/` via the Traceability section.

## Description
- Recurses through the requirements directory, looks for `## Traceability` sections, and ensures each `../adr/<file>.md` link corresponds to a real ADR file.
- Reports missing Traceability/ADR references and returns exit code 1 so CI can fail when links fall out of sync.

### Parameters
| Name | Type | Default |
| --- | --- | --- |
| `RequirementsDir` | string | `docs/requirements` |
| `AdrDir` | string | `docs/adr` |

## Outputs
- Console summary; exits 0 when every requirement links to existing ADRs, otherwise lists errors and exits 1.

## Related
- `tools/Link-RequirementToAdr.ps1`
- `docs/adr/README.md`
