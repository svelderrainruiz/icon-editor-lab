# Prepare-FixtureViDiffs.ps1

**Path:** `tools/icon-editor/Prepare-FixtureViDiffs.ps1`

## Synopsis
Generates (or stubs) `vi-diff-requests@v1` JSON for fixture-only VI changes so LVCompare can be queued against VIP outputs.

## Description
- Current implementation is a stub used during local validation dry runs: it logs the invocation, creates the output directory, and writes a canned `vi-diff-requests.json` file pointing to `StubTest.vi`.
- Real implementation will diff fixture artifacts vs the repo baseline and emit compare requests; until then, the stub allows downstream tooling to exercise the handshake without touching LabVIEW.

### Parameters
| Name | Type | Notes |
| --- | --- | --- |
| `ReportPath` | string | Placeholder for future report input. |
| `BaselineManifestPath` | string | Placeholder for future baseline data. |
| `BaselineFixturePath` | string | Placeholder for future fixture bundles. |
| `OutputDir` | string | Directory where the stub writes `vi-diff-requests.json`. |
| `ResourceOverlayRoot` | string | Reserved for future use. |

## Outputs
- `vi-diff-requests.json` containing a single stub request.

## Related
- `tools/icon-editor/Prepare-VipViDiffRequests.ps1`
- `docs/LVCOMPARE_LAB_PLAN.md`
