# Update-IconEditorFixtureReport.ps1

**Path:** `tools/icon-editor/Update-IconEditorFixtureReport.ps1`

## Synopsis
Run `Describe-IconEditorFixture.ps1` against a built VIP, capture `fixture-report.json`, and optionally emit a lightweight manifest for fixture-only assets.

## Description
- Resolves the repo root via git, ensures `tools/icon-editor/Describe-IconEditorFixture.ps1` exists, and validates that `-FixturePath` points to a VIP file.
- Executes the descriptor script (in a clean `pwsh` process) with optional resource overlay content, yielding a JSON summary stored at `<ResultsRoot>/fixture-report.json` (default `tests/results/_agent/icon-editor`).
- When `-ManifestPath` is supplied, converts the `fixtureOnlyAssets` section into a deterministic manifest (`icon-editor/fixture-manifest@v1`) keyed by category/path with hash + size metadata—useful for traceability or change reviews.
- Parameters such as `-SkipDocUpdate`, `-CheckOnly`, and `-NoSummary` exist for backward compatibility; only `-NoSummary` suppresses the returned object.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `FixturePath` | string (required) | — | Icon Editor fixture VIP produced by Simulate/real builds. |
| `ManifestPath` | string | — | When set, writes `icon-editor/fixture-manifest@v1` JSON to this path. |
| `ResultsRoot` | string | `tests/results/_agent/icon-editor` | Directory receiving `fixture-report.json` (and descriptor scratch). |
| `ResourceOverlayRoot` | string | `vendor/labview-icon-editor/resource` | Override overlay folder used during description. |
| `SkipDocUpdate` | switch | No-op | Retained for legacy usage; ignored. |
| `CheckOnly` | switch | No-op | Retained for legacy usage; emits warning. |
| `NoSummary` | switch | Off | Suppress returning the parsed summary object. |

## Outputs
- `<ResultsRoot>/fixture-report.json` — JSON blob from `Describe-IconEditorFixture.ps1`.
- Optional manifest written to `ManifestPath`.
- Returns the parsed summary (unless `-NoSummary`).

## Exit Codes
- `0` — Report generated successfully.
- Non-zero — Missing scripts/fixtures, invalid overlay path, or descriptor failures.

## Related
- `tools/icon-editor/Describe-IconEditorFixture.ps1`
- `tools/icon-editor/Simulate-IconEditorBuild.ps1`

