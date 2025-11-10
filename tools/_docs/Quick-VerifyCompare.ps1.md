# Quick-VerifyCompare.ps1

**Path:** `tools/Quick-VerifyCompare.ps1`

## Synopsis
Fast smoke test for `Invoke-CompareVI.psm1` that creates temporary base/head VIs (or uses provided paths) and prints compare timing/diff status.

## Description
- Imports `scripts/CompareVI.psm1`, creates temporary `.vi` files when `-Base`/`-Head` aren't supplied, and optionally forces identical paths with `-Same`.
- Calls `Invoke-CompareVI` with a mocked executor (to avoid requiring LVCompare.exe) and prints:
  - Base/Head paths
  - Exit code, diff flag, duration seconds/nanoseconds
  - Optional Markdown summary when `-ShowSummary` is set.
- Designed for local validation or debugging of CompareVI plumbing without running the full GitHub Action.

### Parameters
| Name | Type | Notes |
| --- | --- | --- |
| `Base` | string | Existing VI path; auto-generated when omitted. |
| `Head` | string | Existing VI path; auto-generated when omitted (or same as Base when `-Same`). |
| `Same` | switch | Compare the exact same file (expect exit code 0, diff false). |
| `ShowSummary` | switch | Emit a Markdown-style summary block after the stats. |

## Outputs
- Console summary plus optional Markdown block; temporary files cleaned up unless custom paths are provided.

## Related
- `scripts/CompareVI.psm1`
- `tools/Run-CompareSequence.ps1`
