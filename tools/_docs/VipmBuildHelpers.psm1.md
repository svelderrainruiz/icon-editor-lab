# VipmBuildHelpers.psm1

**Path:** `tools/icon-editor/VipmBuildHelpers.psm1`

## Synopsis
Telemetry + orchestration helpers for VIPM package builds driven by icon-editor scripts.

## Description
- `Initialize-VipmBuildTelemetry` / `Write-VipmBuildTelemetry` create JSON logs under `tests/results/_agent/icon-editor/vipm-cli-build`, capturing start/end timestamps, toolchain/provider, and artifact metadata.
- `Get-VipmBuildArtifacts` enumerates recently built `.vip` artifacts (or other filters) so automation can publish or summarize the outputs.
- `Invoke-VipmPackageBuild` wraps the VIPM modify/build/close scripts (via `Invoke-IconEditorVipPackaging`) and records telemetry; `-DisplayOnly` simply snapshots existing artifacts without running VIPM.

## Related
- `tools/icon-editor/Invoke-VipmDependencies.ps1`
- `tools/icon-editor/Publish-LocalArtifacts.ps1`
