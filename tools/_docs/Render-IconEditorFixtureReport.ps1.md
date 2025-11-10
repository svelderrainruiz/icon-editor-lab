# Render-IconEditorFixtureReport.ps1

**Path:** `tools/icon-editor/Render-IconEditorFixtureReport.ps1`

## Synopsis
Generates a Markdown report (and optionally updates `docs/ICON_EDITOR_PACKAGE.md`) summarizing the icon-editor fixture package state: hashes, custom actions, artifacts, and fixture-only assets.

## Description
- Ensures a fixture report JSON exists by invoking `Describe-IconEditorFixture.ps1` when necessary, then loads the summary to extract package metadata, artifact hashes, smoke status, and fixture-only asset lists.
- Produces sections covering package layout, stakeholder summary, hash comparisons vs repository sources, fixture-only manifests, and manifest deltas (when `ICON_EDITOR_BASELINE_MANIFEST_PATH` is set).
- When `-UpdateDoc` is supplied, replaces the `<!-- icon-editor-report:start --> ... end` block inside `docs/ICON_EDITOR_PACKAGE.md` with the freshly rendered Markdown.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `ReportPath` | string | auto (`tests/results/_agent/icon-editor/fixture-report.json`) | Existing fixture report; generated if missing. |
| `FixturePath` | string | - | Explicit path to a fixture bundle to analyze. |
| `OutputPath` | string | - | Destination Markdown file (written only when provided). |
| `UpdateDoc` | switch | Off | Replace the doc block in `docs/ICON_EDITOR_PACKAGE.md`. |

## Outputs
- Markdown summary written to stdout (and optionally to `OutputPath` or `docs/ICON_EDITOR_PACKAGE.md`).
- When baseline manifest env vars exist, prints counts of added/removed/changed fixture-only assets.

## Related
- `tools/icon-editor/Describe-IconEditorFixture.ps1`
- `docs/ICON_EDITOR_PACKAGE.md`
