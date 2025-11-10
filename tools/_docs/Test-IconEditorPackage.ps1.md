# Test-IconEditorPackage.ps1

**Path:** `tools/icon-editor/Test-IconEditorPackage.ps1`

## Synopsis
Smoke-test one or more Icon Editor VIPs by inspecting required payloads (x86/x64 lvlibp files, build metadata) and write a summary suitable for CI gating.

## Description
- Accepts VIP paths explicitly or, when `-ManifestPath` is set, derives them from `manifest.artifacts[*].path` entries marked `kind='vip'`.
- Creates/uses `<ResultsRoot>/package-smoke-summary.json` (default: manifest directory or `./package-smoke`) to record results.
- For each VIP it opens the archive, counts `*.lvlibp` entries, and ensures both `lv_icon_x86.lvlibp` and `lv_icon_x64.lvlibp` exist; missing files mark the item `fail`.
- When `-VersionInfo` is provided (hash table with `major/minor/patch/build`), searches `support/**/build.txt` entries to confirm the expected version text exists, recording the match status.
- If no VIPs are available and `-RequireVip` is set, the script throws; otherwise it writes a `status='skipped'` summary.
- Returns the summary object so callers (e.g., `Simulate-IconEditorBuild`) can embed it in their manifests.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `VipPath` | string[] | Derived from manifest | Explicit VI Package paths to inspect. |
| `ManifestPath` | string | — | Provide to auto-discover VIP artifact paths. |
| `ResultsRoot` | string | Manifest directory or `package-smoke` | Where `package-smoke-summary.json` is written. |
| `VersionInfo` | hashtable | — | Expected version parts for `support/**/build.txt` validation. |
| `RequireVip` | switch | Off | Fail when no VIP artifacts can be located. |

## Outputs
- `<ResultsRoot>/package-smoke-summary.json` (`icon-editor/package-smoke@v1`) describing the overall status and per-VIP checks.
- Returns the summary object to the caller.

## Exit Codes
- `0` — All necessary VIPs were inspected and either passed or were skipped intentionally.
- Non-zero — Missing manifest/VIP when required, or unhandled archive errors.

## Related
- `tools/icon-editor/Simulate-IconEditorBuild.ps1`
- `tools/icon-editor/Test-IconEditorFixture.ps1`
