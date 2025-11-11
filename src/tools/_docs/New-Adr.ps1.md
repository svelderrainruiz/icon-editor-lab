# New-Adr.ps1

**Path:** `tools/New-Adr.ps1`

## Synopsis
Bootstraps a new Architecture Decision Record (ADR) under `docs/adr/` and updates the ADR index table.

## Description
- Determines the next ADR number (`0000`, `0001`, …) by scanning `docs/adr/*.md`, slugifies the title into a filename (`0004-fix-vi-compare.md`), and writes a template with sections for Context/Decision/Consequences/References.
- Updates `docs/adr/README.md` by inserting a new table row containing the ADR link, title, status, date, and links to any referenced requirement docs.
- Optional `-Requirements` entries auto-link requirement Markdown files under `docs/requirements`; missing files trigger warnings so the author can fix typos.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Title` | string (required) | - | ADR title (used for slug + template heading). |
| `Status` | string | `Draft` | Initial ADR status noted in the template + index. |
| `Date` | string | `yyyy-MM-dd (today)` | Override when backfilling older decisions. |
| `Requirements` | string[] | - | Relative paths or filenames of requirement docs to cross-link. |

## Outputs
- Creates `docs/adr/<id>-<slug>.md` with placeholder content.
- Updates `docs/adr/README.md` table; prints the new ADR ID/path to stdout.

## Related
- `docs/requirements/Icon-Editor-Lab_SRS.md`
- `tools/Validate-AdrLinks.ps1`
