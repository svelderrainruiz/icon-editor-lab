# Describe-IconEditorFixture.ps1

**Path:** `tools/icon-editor/Describe-IconEditorFixture.ps1`

## Synopsis
Generates a stub `icon-editor/fixture-report@v1` JSON so downstream renderers have structured content even when fixture packaging isn’t available locally.

## Description
- Validates `-FixturePath` (required) and writes a minimal fixture summary containing artifact metadata, runner dependency hashes, and stakeholder placeholders.
- Appends a stub entry to `Global:InvokeValidateLocalStubLog` to signal which command/parameters were invoked (used by higher-level scripts in dry-run scenarios).
- When `-OutputPath` is provided, directories are auto-created before the JSON is written.
- `-SkipResourceOverlay` and `-ResourceOverlayRoot` flags mirror the real snapshot command so callers can pass through their existing arguments during simulation.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `FixturePath` | string (required) | - | VIP/fixture artifact to describe. |
| `ResultsRoot` | string | - | Optional location used when assembling derived metadata. |
| `OutputPath` | string | - | When supplied, receives the JSON report. |
| `KeepWork` | switch | Off | Placeholder flag (kept for parity with the real command). |
| `SkipResourceOverlay` | switch | Off | Indicates overlay assets were skipped. |
| `ResourceOverlayRoot` | string | - | Root folder for overlay assets (when not skipped). |

## Outputs
- Fixture summary JSON matching `icon-editor/fixture-report@v1`; defaults to stdout when `-OutputPath` is omitted.
- Appends stub metadata to `Global:InvokeValidateLocalStubLog`.

## Exit Codes
- `0` on success; non-zero when `-FixturePath` is missing or unwritable.

## Related
- `tools/icon-editor/Invoke-IconEditorSnapshotFromRepo.ps1`
- `docs/ICON_EDITOR_LAB_MIGRATION.md`
