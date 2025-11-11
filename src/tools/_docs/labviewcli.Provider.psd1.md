# labviewcli.Provider.psd1

**Path:** `tools/providers/labviewcli/labviewcli.Provider.psd1`

## Synopsis
Module manifest that exposes the native LabVIEW CLI provider (`Provider.psm1`) to `tools/LabVIEWCli.psm1` and the bundle exporter.

## Description
- Declares `RootModule = 'Provider.psm1'` and `FunctionsToExport = '*'`, ensuring the provider’s `New-LVProvider` factory is visible when `tools/LabVIEWCli.psm1` enumerates `tools/providers/*`.
- Identifies the provider bundle (`ModuleVersion 0.0.1`, GUID `3686396a-50d3-4f06-b4db-8390da401906`, author `compare-vi-cli-action`) so `tools/Export-LabTooling.ps1` can stamp the manifest into the published toolkit.
- No cmdlets/aliases are exported directly; consuming scripts import the module and call `New-LVProvider` to register the provider with the central dispatcher.

## Related
- `tools/providers/labviewcli/Provider.psm1`
- `tools/LabVIEWCli.psm1`
- `tools/providers/gcli/gcli.Provider.psd1`
