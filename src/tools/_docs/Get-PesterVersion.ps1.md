# Get-PesterVersion.ps1

**Path:** `tools/Get-PesterVersion.ps1`

## Synopsis
Resolves the repo’s pinned Pester version (from `policy/tool-versions.json` or a baked-in default) and optionally emits it to GitHub env/output files.

## Description
- Default version: `5.7.1`.
- When `policy/tool-versions.json` defines a `pester` entry, that value overrides the default.
- `-EmitEnv` writes `PESTER_VERSION=<value>` to `$GITHUB_ENV`; `-EmitOutput` writes `version=<value>` to `$GITHUB_OUTPUT`.
- With no switches, the resolved version is printed to stdout for use in scripts or local tooling.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `EmitEnv` | switch | Off | Append `PESTER_VERSION` to GitHub env file. |
| `EmitOutput` | switch | Off | Append `version` to GitHub output file. |

## Exit Codes
- `0` unless an unexpected exception occurs while reading the policy file.

## Related
- `policy/tool-versions.json`
- `tools/Watch-Pester.ps1`
