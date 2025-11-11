# IconEditorPackage.psm1

**Path:** `tools/icon-editor/IconEditorPackage.psm1`

## Synopsis
Helpers for building and publishing icon-editor VIP packages: resolves vendor roots, loads VendorTools/GCli/VIPM modules, and orchestrates g-cli operations.

## Description
- Resolves the repo root (`vendor/icon-editor`) and log directories, then imports supporting modules (`VendorTools.psm1`, `GCli.psm1`, `Vipm.psm1`) on demand.
- Key functions include:
  - `Get-IconEditorPackageName/Path` – derive VIP filenames from `.vipb` buildspecs and version numbers.
  - `Invoke-IconEditorProcess` – wrapper around g-cli/VIPM commands for consistent logging.
  - VIP build/install helpers that call g-cli providers (see `tools/GCli.psm1`).
- Used by packaging scripts to ensure g-cli and VIPM operations share consistent configuration and logging.

## Related
- `tools/Invoke-VipmCliBuild.ps1`
- `tools/icon-editor/IconEditorDevMode.psm1`
