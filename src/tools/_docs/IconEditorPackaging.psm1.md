# IconEditorPackaging.psm1

**Path:** `tools/vendor/IconEditorPackaging.psm1`

## Synopsis
Provides a structured setup/main/cleanup pipeline for packaging Icon Editor VIPs: modify VIPB metadata, run the vendor build scripts, close LabVIEW, and collect artifacts.

## Description
- Core function `Invoke-IconEditorVipPackaging` accepts script paths for Modify-VIPB, build_vip, and Close-LabVIEW along with helper arguments (VIPB path, release notes, toolchain/provider).
- Executes the provided scripts via an `InvokeAction` scriptblock so callers can inject logging or dry-run behavior.
- After building, copies new `.vip` files from the icon-editor tree into the results directory and returns metadata (`Artifacts`, `Toolchain`, `Provider`) for downstream reporting.
- Validates script existence up front and emits structured console logs for each stage (setup/main/cleanup).

### Parameters (Invoke-IconEditorVipPackaging)
| Name | Type | Notes |
| --- | --- | --- |
| `InvokeAction` | scriptblock (required) | Wrapper used to execute each step (e.g., `&`). |
| `ModifyVipbScriptPath`, `BuildVipScriptPath`, `CloseScriptPath` | string (required) | Paths to vendor scripts. |
| `IconEditorRoot`, `ResultsRoot` | string (required) | Working directories. |
| `ArtifactCutoffUtc` | datetime (required) | Only artifacts newer than this timestamp are collected. |
| `ModifyArguments`, `BuildArguments`, `CloseArguments` | string[] | Optional arguments per script. |
| `VipbRelativePath`, `ReleaseNotesPath`, `Toolchain`, `Provider`, `ArtifactFilter` | string | Additional context/artifact filters. |

## Related
- `tools/icon-editor/IconEditorPackage.psm1`
- `tools/Invoke-VipmCliBuild.ps1`
