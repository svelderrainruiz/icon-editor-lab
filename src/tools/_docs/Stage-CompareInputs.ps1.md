# Stage-CompareInputs.ps1

**Path:** `tools/Stage-CompareInputs.ps1`

## Synopsis
Copy the base/head VI inputs into a temporary staging directory with canonical names (`Base.vi`, `Head.vi`) for downstream LVCompare harnesses.

## Description
- Resolves the provided `BaseVi`/`HeadVi` paths (absolute or relative) and validates they are files (not directories).  
- Creates a temporary directory (under `WorkingRoot` or the system temp path), copies the VIs, and returns a PSCustomObject containing:
  - `Base` — staged base VI path
  - `Head` — staged head VI path
  - `Root` — staging directory for cleanup
- Preserves file extensions for a set of known LabVIEW artifacts (.vi, .ctl, .lvlib, etc.) so compares remain context-aware.
- Used by `Run-HeadlessCompare.ps1` (unless `-UseRawPaths`) and other LVCompare flows to avoid mutating the original files.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `BaseVi` | string (required) | — | Source path for the “base” VI. |
| `HeadVi` | string (required) | — | Source path for the “head” VI. |
| `WorkingRoot` | string | System temp | Optional parent for the staging directory. |

## Exit Codes
- `0` — Staging succeeded (object returned to caller).
- `!=0` — Failed to resolve or copy the inputs (throws an exception).

## Related
- `tools/Run-HeadlessCompare.ps1`
- `tools/TestStand-CompareHarness.ps1`
- `docs/LVCOMPARE_LAB_PLAN.md`
