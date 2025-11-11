# Diagnose-LabVIEWSetup.ps1

**Path:** `tools/Diagnose-LabVIEWSetup.ps1`

## Synopsis
Checks whether required LabVIEW/VIPM toolchains are installed for source, report, and packaging lanes, emitting a readiness report.

## Description
- Imports `VendorTools.psm1` to discover LabVIEW 2021/2025 installs, LVCompare, LabVIEWCLI, G-CLI, and VIPM.
- Builds three “lanes”:
  - `source` (LabVIEW 2021 x86/x64 + G-CLI)
  - `report` (LabVIEW 2025 x64, LabVIEWCLI, LVCompare)
  - `packaging` (LabVIEW 2021 x86 + VIPM)
- Prints a colorized summary indicating which requirements are present; exits non-zero if any lane is missing prerequisites.
- `-Json` returns the structured readiness object (useful for CI artifacts).

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Json` | switch | Off | Emit JSON (`lanes[]` with `requirements` and `missing`) instead of console output. |

## Exit Codes
- `0` when all lanes are ready.
- `1` when any required toolchain is missing.

## Related
- `tools/VendorTools.psm1`
- `docs/LABVIEW_GATING.md`
