# PackedLibraryBuild.psm1

**Path:** `tools/vendor/PackedLibraryBuild.psm1`

## Synopsis
Utility module that orchestrates g-cli packed library builds by running vendor-provided modify/build/close/rename scripts for each target configuration.

## Description
- `Invoke-LVPackedLibraryBuild` accepts a script block (`InvokeAction`) that actually shells out to the vendor scripts (usually g-cli). For every target it:
  1. Runs the modify/build script with the provided arguments.
  2. Optionally calls a close script (to shut down LabVIEW between builds).
  3. Runs the rename script to place the .lvlibp in the correct artifact location (supports `{{BaseArtifactPath}}` placeholder).
- Cleans out previous artifacts (`CleanupPatterns`) before starting and raises helpful errors when required scripts/arguments are missing.
- Allows callers to supply `OnBuildError` to handle/normalize vendor failures.

## Related
- `tools/icon-editor/VipmBuildHelpers.psm1`
- `tools/icon-editor/Invoke-VipmPackageBuild.ps1`
