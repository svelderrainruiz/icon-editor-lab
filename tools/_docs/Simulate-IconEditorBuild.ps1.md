# Simulate-IconEditorBuild.ps1

**Path:** `tools/icon-editor/Simulate-IconEditorBuild.ps1`

## Synopsis
Unpack an Icon Editor fixture VIP, overlay repo resources, harvest lvlibp artifacts, and emit a build manifest without invoking the full NI build farm.

## Description
- Requires a fixture VI Package (`-FixturePath` or `ICON_EDITOR_FIXTURE_PATH`). The script extracts it to a temp directory and verifies the embedded `spec` file and nested system VIP.
- Copies the top-level fixture VIP, nested system VIP, and any discovered `*.lvlibp` plug-ins into `-ResultsRoot` (default `tests/results/_agent/icon-editor-simulate`) while recording artifact metadata (name, size, kind).
- Parses the fixture version (`major.minor.patch.build`) and optionally compares it with `-ExpectedVersion` (hash table or JSON).
- When `Test-IconEditorPackage.ps1` is available it runs the package smoke test against the captured VIPs (unless `-ExpectedVersion` indicates otherwise) and embeds the summary in the manifest.
- If `-VipDiffOutputDir` is provided, calls `Prepare-VipViDiffRequests.ps1` to generate `vi-diff-requests.json` so engineers can diff VI contents downstream.
- Writes `manifest.json` (`icon-editor/build@v1`) describing artifacts, version info, simulation status, and optional vipDiff/packageSmoke blocks. Temporary extraction directories are removed unless `-KeepExtract` is set.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `FixturePath` | string | `ICON_EDITOR_FIXTURE_PATH` | Required path to the fixture VIP. |
| `ResultsRoot` | string | `tests/results/_agent/icon-editor-simulate` | Destination for extracted artifacts + manifest. |
| `ExpectedVersion` | object/string | — | Optional JSON/hashtable with `major/minor/patch/build/commit` to record in the manifest. |
| `VipDiffOutputDir` | string | — | Enables VI diff request generation under this directory. |
| `VipDiffRequestsPath` | string | `<VipDiffOutputDir>/vi-diff-requests.json` | Overrides the request file location. |
| `KeepExtract` | switch | Off | Skip cleanup of temporary extraction folders. |
| `SkipResourceOverlay` | switch | Off | Avoid copying repo `vendor/icon-editor/resource` files into the simulated install. |
| `ResourceOverlayRoot` | string | `vendor/icon-editor/resource` | Custom overlay root; ignored when `-SkipResourceOverlay`. |

## Outputs
- `<ResultsRoot>/manifest.json` (`icon-editor/build@v1`) with artifact metadata, version info, vipDiff/packageSmoke summaries.
- Copies of the fixture VIP, system VIP, and each `*.lvlibp` plug-in in `<ResultsRoot>`.
- Optional vi-diff request bundle in `VipDiffOutputDir`.

## Exit Codes
- `0` — Simulation succeeded.
- Non-zero — Missing fixture/spec/VIP files, failing smoke tests (when `Test-IconEditorPackage` throws), or unexpected I/O errors.

## Related
- `tools/icon-editor/Test-IconEditorPackage.ps1`
- `tools/icon-editor/Prepare-VipViDiffRequests.ps1`
