# Invoke-VipmCliBuild.ps1

**Path:** `tools/icon-editor/Invoke-VipmCliBuild.ps1`

## Synopsis
Automate VIPM CLI builds for the Icon Editor package: sync repo content, apply VIPCs, run the CLI build, and capture results/telemetry.

## Description
- Resolves `RepoRoot`/`IconEditorRoot` and prepares `tests/results/_agent/icon-editor/vipm-cli-build`.
- Optionally generates temporary wrapper modules (VIPM expects specific layout) via `Ensure-VendorModule`.
- Steps (when not skipped):
  1. Sync the repo `RepoSlug` into the Icon Editor working tree (`-SkipSync` bypasses this).
  2. Apply `icon-editor.vipc` dependencies (`-SkipVipcApply` bypasses).
  3. Run VIPM CLI (`vipmcl.exe`) to build packages for the requested `MinimumSupportedLVVersion` / `PackageMinimumSupportedLVVersion` and `PackageSupportedBitness`.  
  4. Perform rogue-LabVIEW checks and cleanup (`-SkipRogueCheck` / `-SkipClose` control these guards).
- Writes build logs + output artifacts under the results root; emits the build version (Major.Minor.Patch.Build) for traceability.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `RepoRoot` | string | Auto-resolved | Root of the Icon Editor repo. |
| `IconEditorRoot` | string | `vendor/icon-editor` | Working directory for VIPM CLI. |
| `RepoSlug` | string | `LabVIEW-Community-CI-CD/labview-icon-editor` | Repo to sync into `IconEditorRoot`. |
| `MinimumSupportedLVVersion` | int | `2023` | Dev-mode/g-cli minimum (32 + 64 bit). |
| `PackageMinimumSupportedLVVersion` | int | `2026` | Minimum version embedded in the VIP. |
| `PackageSupportedBitness` | int (32/64) | `64` | Bitness of the built package. |
| `SkipSync` / `SkipVipcApply` / `SkipBuild` | switch | Off | Skip individual stages. |
| `SkipRogueCheck` / `SkipClose` | switch | Off | Disable rogue-LabVIEW enforcement/cleanup. |
| `Major/Minor/Patch/Build` | int | `1/4/1/<yyMMdd>` | Package version components. |
| `ResultsRoot` | string | `tests/results/_agent/icon-editor/vipm-cli-build` | Output directory. |
| `VerboseOutput` | switch | Off | Enable detailed logging. |

## Exit Codes
- `0` — VIPM CLI build finished (even if some stages were skipped).
- `!=0` — Failure syncing, applying VIPC, or running the CLI.

## Related
- `tools/icon-editor/Invoke-IconEditorBuild.ps1`
- `tools/icon-editor/Invoke-IconEditorVipPackaging.ps1`
- `docs/ICON_EDITOR_LAB_MIGRATION.md`
