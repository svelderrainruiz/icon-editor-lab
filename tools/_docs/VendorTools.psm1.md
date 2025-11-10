# VendorTools.psm1

**Path:** `tools/VendorTools.psm1`

## Synopsis
Utility module with shared helpers for resolving repo root, LabVIEW/VIPM configuration, and other vendor-specific paths used across compare, VIPM, and drift workflows.

## Description
- Provides cross-platform helpers such as:
  - `Resolve-RepoRoot` – run `git rev-parse --show-toplevel`, falling back to the current directory.
  - `Get-LabVIEWConfigObjects` / `Get-VersionedConfigValue` – load `configs/labview-paths*.json` and extract version/bitness-specific properties (LabVIEW, LVCompare, VIPM paths, CLI aliases, etc.).
  - `Resolve-VipmPath` – look up VIPM executables via env vars, config files, or canonical install locations.
  - `Resolve-CommandPath`, `Set-ConsoleUtf8`, plus numerous small path/encoding utilities used by VIPM + LabVIEW scripts.
- Also exports scenario-specific helpers like `Resolve-VIPMPath`, `Resolve-CommandPath`, and `Get-VIBucketMetadata`, enabling other scripts to keep logic focused on their tasks.
- No stateful side effects; scripts import this module to reuse common logic when resolving vendor tools.

## Exports (selected)
- `Resolve-RepoRoot`
- `Get-LabVIEWConfigObjects`
- `Get-VersionedConfigValue`
- `Resolve-CommandPath`
- `Resolve-VIPMPath`
- `Set-ConsoleUtf8`

## Related
- `tools/New-LVCompareConfig.ps1`
- `tools/Vipm/*.ps1`
