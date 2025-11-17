# Publish-LocalArtifacts.ps1

**Path:** `tools/icon-editor/Publish-LocalArtifacts.ps1`

## Status
**Retired.** The script now throws immediately with guidance to use the staged publish
helpers:

1. `tools/Stage-XCliArtifact.ps1`
2. `tools/Test-XCliReleaseAsset.ps1`
3. `tools/Promote-XCliArtifact.ps1`
4. `tools/Upload-XCliArtifact.ps1`

These steps are wired into the VS Code Stage/Test/Promote/Upload tasks and
`tools/Invoke-XCliTestPlanScenario.ps1`. Running the legacy script is no longer
supported because it bypassed the required Stage → Validate → QA → Upload flow.
