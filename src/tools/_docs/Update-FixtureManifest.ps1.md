# Update-FixtureManifest.ps1

**Path:** `tools/Update-FixtureManifest.ps1`

## Synopsis
Recompute SHA256/byte-size metadata for fixture VIs and refresh `fixtures.manifest.json`, optionally embedding a deterministic pair digest with expected outcome hints.

## Description
- Uses `VI1.vi`/`VI2.vi` (relative to repo root) as the canonical fixture pair; errors if either file is missing.
- Requires an explicit opt-in (`-Allow` or `-Force`) to prevent accidental manifest churn in CI; `-DryRun` previews changes without writing.
- Writes `fixtures.manifest.json` with schema `fixture-manifest-v1`, `generatedAt`, and an `items` array containing relative paths, SHA256 hashes, and byte counts.
- `-InjectPair` adds a `pair` block (`fixture-pair/v1`) that stores a canonical digest; `-SetExpectedOutcome` and `-SetEnforce` let maintainers describe whether differences are required vs. optional notices.
- Preserves existing pair metadata when not explicitly overridden.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `-Allow` | switch | Off | Required (or `-Force`) to permit edits. |
| `-Force` | switch | Off | Same as `-Allow`; provided for legacy scripts. |
| `-DryRun` | switch | Off | Report whether content would change without writing. |
| `-Output` | string | `fixtures.manifest.json` | Destination relative to repo root. |
| `-InjectPair` | switch | Off | Emit the pair digest section. |
| `-SetExpectedOutcome` | string | `any` (prior value) | Override `pair.expectedOutcome`. |
| `-SetEnforce` | string | `notice` (prior value) | Override `pair.enforce` hint. |

## Outputs
- Updated `fixtures.manifest.json` (or alternate `-Output`) in the repo root.
- Console messages indicating whether the manifest changed or was skipped (dry run / unchanged).

## Exit Codes
- `0` — Manifest already up to date or successfully written.
- `1` — Missing `-Allow`/`-Force`.
- `2` — Fixture file missing or unreadable.
- Other non-zero values bubble up from I/O or JSON serialization failures.

## Related
- `tools/Verify-FixtureCompare.ps1`
- `tools/Validate-Fixtures.ps1`
