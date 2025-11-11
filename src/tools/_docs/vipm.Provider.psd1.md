# vipm.Provider.psd1

**Path:** `tools/providers/vipm/vipm.Provider.psd1`

## Synopsis
Manifest that packages the classic VIPM provider (`Provider.psm1`) for auto-registration with `tools/LabVIEWCli.psm1` and bundle exports.

## Description
- Declares `RootModule = 'Provider.psm1'`, `ModuleVersion = 0.0.1`, and GUID `2ec0cceb-8d62-4b1a-9a73-...` so bundle consumers can track which provider revision shipped.
- `FunctionsToExport = '*'`, ensuring `New-LVProvider` is visible when `LabVIEWCli.psm1` enumerates provider modules under `tools/providers/*`.
- Metadata (Author `compare-vi-cli-action`, Company `LabVIEW Community CI/CD`) aligns with the artifacts produced by `tools/Export-LabTooling.ps1`.

## Related
- `tools/providers/vipm/Provider.psm1`
- `tools/LabVIEWCli.psm1`
