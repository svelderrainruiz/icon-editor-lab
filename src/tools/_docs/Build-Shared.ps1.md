# Build-Shared.ps1

**Path:** `tools/Build-Shared.ps1`

## Synopsis
Restores, builds, and optionally packs the `CompareVi.Shared` .NET project that underpins CompareVI tooling.

## Description
- Resolves `src/CompareVi.Shared/CompareVi.Shared.csproj` relative to the repo root and runs `dotnet restore` + `dotnet build -c Release`.
- When `-Pack` is supplied, produces NuGet packages into `artifacts/` via `dotnet pack -c Release --no-build`, then lists the generated `.nupkg` paths.
- Emits `dotnet --info` for traceability.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Pack` | switch | Off | Adds `dotnet pack` step and prints resulting package paths. |

## Exit Codes
- `0` when build (and optional pack) succeed.
- Non-zero when the project file is missing or `dotnet` returns an error.

## Related
- `src/CompareVi.Shared/CompareVi.Shared.csproj`
- `tools/Build-ToolsImage.ps1`
