# Get-BranchProtectionRequiredChecks.ps1

**Path:** `tools/Get-BranchProtectionRequiredChecks.ps1`

## Synopsis
Queries the GitHub API for a branch’s required status checks and returns the configured contexts.

## Description
- Requires repo owner, name, and branch; uses `GITHUB_TOKEN` (or `GH_TOKEN`) to call `GET /repos/{owner}/{repo}/branches/{branch}/protection`.
- Response handling:
  - When status checks exist, returns `status='available'` plus the `contexts` (or newer `checks.context` values).
  - When branch protection isn’t configured (HTTP 404), returns `status='unavailable'`.
  - Missing tokens or API failures yield `status='unavailable'`/`'error'` with explanatory notes.
- Useful for tooling that needs to ensure compare workflows set the correct required checks before enabling branch protection policies.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Owner` | string (required) | - | Repository owner/org. |
| `Repository` | string (required) | - | Repository name. |
| `Branch` | string (required) | - | Branch to inspect. |
| `Token` | string | `$env:GITHUB_TOKEN` or `$env:GH_TOKEN` | Overrides the default token resolution. |
| `ApiBaseUrl` | string | `https://api.github.com` | Base URL (override for GH Enterprise). |

## Outputs
- `[pscustomobject]` with `status`, `contexts`, and `notes`.

## Exit Codes
- Always `0`; API errors are captured in the returned object rather than raising terminating errors.

## Related
- `tools/Update-SessionIndexBranchProtection.ps1`
