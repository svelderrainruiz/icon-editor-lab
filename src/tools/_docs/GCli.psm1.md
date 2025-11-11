# GCli.psm1

**Path:** `tools/GCli.psm1`

## Synopsis
Facade for g-cli providers: discovers provider modules, registers them, and exposes helper functions to resolve binaries and build argument lists for VIPB/VIPC operations.

## Description
- Imports all provider modules under `tools/providers/*/` (e.g., `providers/gcli/Provider.psm1`), calling each module’s `New-GCliProvider` to register operations like `VipbBuild` or `VipcInstall`.
- Exposes helper functions:
  - `Register-GCliProvider` – adds a provider object that implements `Name()`, `ResolveBinaryPath()`, `Supports()`, and `BuildArgs()`.
  - `Get-GCliProviders` / `Get-GCliProviderByName` – enumerate or retrieve providers.
  - `Import-GCliProviderModules` – auto-loads available providers at runtime; invoked when the module is imported.
- Used by toolchain scripts (`Invoke-VipmCliBuild`, `IconEditorPackage` automation) to build g-cli command lines consistently.

## Related
- `tools/providers/gcli/Provider.psm1`
- `tools/Invoke-VipmCliBuild.ps1`
