# Set-IntegrationEnv.Sample.ps1

**Path:** `tools/Set-IntegrationEnv.Sample.ps1`

## Synopsis
Sample helper that resolves two VI paths and exports them to the current PowerShell session as `LV_BASE_VI` / `LV_HEAD_VI` for CompareVI test runs.

## Description
- Intended as a starting point for local integration testing. Update the default VI paths (or pass them via parameters) to real LabVIEW files before invoking.
- Validates both paths; unresolved files trigger warnings and leave the corresponding env var blank so downstream scripts fail fast.
- Echoes the resolved absolute paths for visibility and warns if the canonical LVCompare binary is missing.
- Variables are scoped to the invoking shell (handy for `pwsh` sessions that run `tools/Run-HeadlessCompare.ps1` or TestStand harnesses).

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `BaseVi` | string | `C:\Path\To\VI1.vi` | Source VI representing the “base” side of the compare. |
| `HeadVi` | string | `C:\Path\To\VI2.vi` | Source VI for the “head” side. |

## Outputs
- Sets `LV_BASE_VI` and `LV_HEAD_VI` in the current environment when the files resolve.
- Console warnings whenever the sample paths do not exist or LVCompare is missing from the canonical installation.

## Exit Codes
- `0` — Script completed (even if paths were missing; check warnings).
- `!=0` — Only occurs if PowerShell itself fails (e.g., permission error).

## Related
- `tools/Run-HeadlessCompare.ps1`
- `docs/LVCOMPARE_LAB_PLAN.md`
