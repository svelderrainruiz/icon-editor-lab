# Publish-Cli.ps1

**Path:** `tools/Publish-Cli.ps1`

## Synopsis
Publishes the CompareVI CLI (`src/CompareVi.Tools.Cli`) for every requested RID, producing zipped/tarred artifacts plus SHA256 sums in `artifacts/cli`.

## Description
- Resolves the CLI version from `Directory.Build.props`, then runs `dotnet publish` for each RID listed in `-Rids` (defaults to `win-x64`, `linux-x64`, `osx-x64`).
- Builds both framework-dependent and self-contained layouts when the corresponding switches are enabled, optionally using single-file output for self-contained builds.
- Copies repo metadata (`LICENSE`, `README.md`, `CHANGELOG.md`) into each publish folder, then compresses outputs (`.zip` on Windows, `.tar.gz` elsewhere). All archives are hashed into `SHA256SUMS.txt` so release workflows can verify downloads.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `ProjectPath` | string | `src/CompareVi.Tools.Cli/CompareVi.Tools.Cli.csproj` | CLI project to publish. |
| `Configuration` | string | `Release` | Build configuration passed to `dotnet publish`. |
| `Rids` | string[] | `@('win-x64','linux-x64','osx-x64')` | Runtime identifiers to build. |
| `OutputRoot` | string | `artifacts/cli` | Root folder for publish directories and archives. |
| `FrameworkDependent` | switch | On | Produce framework-dependent builds (`fxdependent/<rid>`). |
| `SelfContained` | switch | On | Produce self-contained builds (`selfcontained/<rid>`). |
| `SingleFile` | switch | On | When building self-contained, request `PublishSingleFile=true`. |

## Outputs
- Published binaries under `<OutputRoot>/fxdependent/<rid>` and `<OutputRoot>/selfcontained/<rid>`.
- Archives named `comparevi-cli-v<version>-<rid>-<flavor>.zip|tar.gz` plus `SHA256SUMS.txt`.

## Exit Codes
- `0` – All publishes succeeded.
- `!=0` – `dotnet publish` or archive/hash steps failed (script stops on first error).

## Related
- `tools/Publish-VICompareSummary.ps1`
- `docs/LVCOMPARE_LAB_PLAN.md`
