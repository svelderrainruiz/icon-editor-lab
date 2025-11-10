# Print-ToolVersions.ps1

**Path:** `tools/Print-ToolVersions.ps1`

## Synopsis
Prints the versions of actionlint, Node.js, npm, and markdownlint-cli2 detected in the repo/tooling environment.

## Description
- Imports `VendorTools.psm1`, resolves each tool on the current PATH (actionlint via `Resolve-ActionlintPath`, Node via `Get-Command`, npm via `npm` package metadata, markdownlint via helper).
- Falls back to `missing`/`unavailable` labels when tools aren’t installed or version queries fail.
- Useful for CI logs and troubleshooting inconsistent developer environments.

## Outputs
- Four console lines (`actionlint`, `node`, `npm`, `markdownlint-cli2`) with version strings.

## Related
- `tools/PrePush-Checks.ps1`
- `tools/dl-actionlint.sh`
