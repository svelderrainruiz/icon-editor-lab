# gcli.Provider.psd1

**Path:** `tools/providers/gcli/gcli.Provider.psd1`

## Synopsis
Manifest for the g-cli provider module that registers VIPB/VIPC operations with the GCli facade.

## Description
- Sets `RootModule = 'Provider.psm1'` and exports `New-GCliProvider` so `tools/GCli.psm1` can dynamically load the provider.
- Metadata identifies the provider (`compare-vi-cli-action`, version `0.0.1`, GUID `366f69cc-56a7-4b9f-aa74-b84d89df7bf2`) used during bundle exports.
- No commands are exported directly; the Provider module supplies a script object consumed by the GCli dispatcher.

## Related
- `tools/providers/gcli/Provider.psm1`
- `tools/GCli.psm1`
