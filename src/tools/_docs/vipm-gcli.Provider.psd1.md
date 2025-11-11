# vipm-gcli.Provider.psd1

**Path:** `tools/providers/vipm-gcli/vipm-gcli.Provider.psd1`

## Synopsis
Manifest for the VIPM g-cli provider so `tools/LabVIEWCli.psm1` can discover and register the g-cli backend.

## Description
- Sets `RootModule = 'Provider.psm1'` and exports every function, exposing the provider’s `New-LVProvider` factory to LabVIEWCli’s auto-loader.
- Captures module identity (version, GUID, author `compare-vi-cli-action`) used when `tools/Export-LabTooling.ps1` bundles provider metadata.
- Enables scripts to select `Provider=vipm-gcli` (e.g., `Invoke-VipmDependencies.ps1`, `Invoke-ProviderComparison.ps1`) so VIPM operations run through the g-cli wrapper instead of desktop VIPM.

## Related
- `tools/providers/vipm-gcli/Provider.psm1`
- `tools/LabVIEWCli.psm1`
- `tools/Vipm/Invoke-ProviderComparison.ps1`
