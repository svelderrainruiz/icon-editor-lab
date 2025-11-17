# Provider.psm1

**Path:** `tools/providers/vipm/Provider.psm1`

## Synopsis
Implements the classic VIPM provider for `tools/LabVIEWCli.psm1`, exposing `InstallVipc` and `BuildVip` operations backed by a locally installed VIPM executable. New automation flows should instead use the vipmcli/g-cli providers.

## Description
- Resolves the classic VIPM binary by checking `Resolve-VIPMPath`, `VIPM_PATH`, and `VIPM_EXE_PATH`, falling back to the `vipm` command on `PATH`. Throws if the executable cannot be located.
- Defines `Get-VipmArgs` to translate normalized operation parameters into the `vipm -vipc/-vipb ...` command line (LabVIEW version/bitness flags, output directory, additional options).
- `New-VipmProvider` returns an object implementing the provider contract (`Name`, `ResolveBinaryPath`, `Supports`, `BuildArgs`); `New-LVProvider` is exported so `LabVIEWCli.psm1` can auto-register this provider during startup.
- For automated VIPC/package flows, prefer the vipmcli/g-cli providers (`tools/providers/vipm-gcli/Provider.psm1` and `tools/providers/gcli/Provider.psm1`) which are wired through x-cli.

## Related
- `tools/LabVIEWCli.psm1`
- `tools/providers/vipm/vipm.Provider.psd1`
- `tools/Vipm/Invoke-ProviderComparison.ps1`
