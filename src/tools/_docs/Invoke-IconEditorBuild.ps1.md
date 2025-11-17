# Invoke-IconEditorBuild.ps1

**Path:** `tools/icon-editor/Invoke-IconEditorBuild.ps1`

## Synopsis
End-to-end Icon Editor build orchestrator: runs g-cli/VIPM builds, optional unit tests, MissingInProject checks, and produces packaging telemetry.

## Description
- Resolves repo + Icon Editor roots, imports `VendorTools`, `PackedLibraryBuild`, `IconEditorPackaging`, `IconEditorDevMode`, and VIPM helpers.
- Validates g-cli installation and ensures all required LabVIEW versions/bitness combos are present (both dev-mode + packaging variants).
- Steps (depending on switches):
  1. Install dependencies via VIPC if `InstallDependencies` is `$true`.
  2. Run g-cli build sequences (`BuildToolchain = 'g-cli'`) or VIPM builds (`'vipm'`), generating VIPs under `tests/results/_agent/icon-editor/packages`.
  3. Optionally run MissingInProject and unit tests (`RunUnitTests`, `SkipMissingInProject`).
  4. Record telemetry via `Initialize-VipmBuildTelemetry` for packaging metadata, dev-mode toggles, and artifact locations.
- Supports both “require packaging” workflows and build-only validation.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `IconEditorRoot` | string | `vendor/icon-editor` | Set when building from a staged bundle. |
| `Major/Minor/Patch/Build` | int | `0` | Version components embedded in the package metadata. |
| `Commit` | string | — | Optional git commit SHA recorded in telemetry. |
| `CompanyName` / `AuthorName` | string | `LabVIEW Community CI/CD` | Branding for generated VIPs. |
| `MinimumSupportedLVVersion` | string | `2023` | Lower bound for g-cli builds (32 + 64 bit). |
| `LabVIEWMinorRevision` | int | `3` | Passed to build scripts. |
| `InstallDependencies` | bool | `$true` | Run VIPC install before building. |
| `SkipPackaging` / `RequirePackaging` | switch | Off | Bypass packaging or fail if packaging did not occur. |
| `RunUnitTests` | switch | Off | Executes `.github/actions/run-unit-tests`. |
| `SkipMissingInProject` | switch | Off | Skip the MissingInProject smoke after build. |
| `ResultsRoot` | string | `tests/results/_agent/icon-editor` | Where telemetry/artifacts land. |
| `BuildToolchain` | string (`g-cli`/`vipm`) | `g-cli` | Choose which build pipeline to invoke. |
| `BuildProvider` | string | — | When set, overrides the default g-cli provider. |
| `PackageMinimumSupportedLVVersion` | string | `2026` | Minimum LabVIEW version baked into VIPs. |
| `PackageLabVIEWMinorRevision` | int | `0` | Minor revision for packaging. |
| `PackageSupportedBitness` | int (32/64) | `64` | Bitness of the packaged build. |

## Exit Codes
- `0` — Build completed (respecting `SkipPackaging`/`RequirePackaging`).
- `!=0` — Failure in dependency install, build, packaging, or validation steps (message includes failing stage).

## Related
- `tools/icon-editor/Invoke-VipmCliBuild.ps1`
- `tools/icon-editor/Invoke-IconEditorVipPackaging.ps1`
- `tools/icon-editor/Run-OneShotBuildAndTests.ps1`
- `docs/ICON_EDITOR_LAB_MIGRATION.md`
