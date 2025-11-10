# Link-RequirementToAdr.ps1

**Path:** `tools/Link-RequirementToAdr.ps1`

## Synopsis
Updates both the requirement doc and ADR so their Traceability/References sections cross-link a requirement (`docs/requirements/*.md`) and an ADR (`docs/adr/*.md`).

## Description
- Resolves the requirement file (accepting relative paths or bare IDs) and the ADR file (`0007-*`). Adds a Traceability entry to the requirement pointing to the ADR and adds a reference row inside the ADR pointing back to the requirement.
- Also updates `docs/adr/README.md` so the ADR’s table row lists the linked requirement(s).
- Ensures the necessary headings exist (`## Traceability`, `## References`) and avoids duplicate entries; throws when files can’t be found.

### Parameters
| Name | Type | Notes |
| --- | --- | --- |
| `Requirement` | string (required) | Requirement file path/ID (e.g., `IELA-SRS-F-001`). |
| `AdrId` | string (required) | ADR ID (e.g., `0007`). |

## Outputs
- Modifies the requirement + ADR Markdown files and the ADR README table; prints a confirmation message.

## Related
- `tools/New-Adr.ps1`
- `docs/requirements/Icon-Editor-Lab_SRS.md`
