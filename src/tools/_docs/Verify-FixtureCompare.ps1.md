# Verify-FixtureCompare.ps1

**Path:** `tools/Verify-FixtureCompare.ps1`

## Synopsis
Cross-check fixture VI pairs against `fixtures.manifest.json` (or supplied inputs), run CompareVI when needed, and emit a pass/fail summary for CI gating.

## Description
- Accepts one of three sources for base/head VIs:
  1. `-ExecJsonPath` — reuse an existing CompareVI execution JSON (copying it into the results directory).
  2. `-BasePath`/`-HeadPath` — explicit VI paths.
  3. Default manifest lookup — resolve base/head entries from `fixtures.manifest.json`, honoring any `pair` block.
- Copies inputs into a temp folder, ensures target results directory exists, and either imports `scripts/CompareVI.psm1` to invoke `Invoke-CompareVI` or reuses the provided exec JSON.
- Computes SHA256 + byte counts for both VIs, compares with manifest expectations, and records whether a diff was expected vs. what CompareVI reported.
- Writes `compare-exec-verify.json` (the exec artifact) and `fixture-verify-summary.json` (`fixture-verify-summary/v1`) under `ResultsDir`.
- Exit code 6 flags mismatches so CI can fail when fixtures drift unexpectedly.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `ManifestPath` | string | `fixtures.manifest.json` | Read to determine canonical fixture metadata. |
| `ResultsDir` | string | `results/local` | Directory receiving exec + summary artifacts. |
| `ExecJsonPath` | string | — | Skip rerun and reuse an existing CompareVI execution JSON. |
| `BasePath` | string | — | Explicit base VI path (paired with `HeadPath`). |
| `HeadPath` | string | — | Explicit head VI path. |
| `VerboseOutput` | switch | Off | Print decision summary and output paths. |

## Outputs
- `<ResultsDir>/compare-exec-verify.json` — CompareVI exec artifact (copied or freshly generated).
- `<ResultsDir>/fixture-verify-summary.json` — Summary with manifest/computed hashes, CLI status, and `ok` flag.
- Console messages when `-VerboseOutput` is set.

## Exit Codes
- `0` — Verification succeeded (CLI diff matched expectations).
- `6` — Manifest expectation disagreed with CompareVI result.
- Other non-zero values indicate missing inputs, manifest parse errors, or CompareVI invocation failures.

## Related
- `tools/Update-FixtureManifest.ps1`
- `tools/Validate-Fixtures.ps1`
