# Vipm.psm1

**Path:** `tools/Vipm.psm1`

## Synopsis
Provider registry/dispatcher for VIPM operations (`InstallVipc`, `BuildVip`, etc.) used throughout the icon-editor tooling.

## Description
- Loads provider modules from `tools/providers/vipm*` (manifest or bare ps1), invokes each module’s `New-VipmProvider`, and stores the resulting provider objects.
- `Get-VipmInvocation` resolves the provider binary path, builds the argument list for the requested operation, and returns a PSCustomObject `{ Provider, Binary, Arguments }` consumed by callers (e.g., `Invoke-VipmDependencies`).
- Allows selecting a provider by name (classic `vipm`, g-cli, future providers) or letting the dispatcher pick the first provider that supports the requested operation.

## Related
- `tools/providers/vipm/Provider.psm1`
- `tools/providers/vipm-gcli/Provider.psm1`
- `tools/icon-editor/VipmDependencyHelpers.psm1`
