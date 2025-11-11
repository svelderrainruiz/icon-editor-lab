# Assert-NoAmbiguousRemoteRefs.ps1

**Path:** `tools/Assert-NoAmbiguousRemoteRefs.ps1`

## Synopsis
Fails fast when a Git remote publishes branches and tags that share the same short name, preventing ambiguous fetch/checkout behavior in CI.

## Description
- Runs `git ls-remote --heads --tags <remote>` and groups the advertised refs by their short name (e.g., `release/24.1`).
- If the same short name exists in multiple namespaces (branch + tag, annotated tag + lightweight tag, etc.), the script throws with a detailed list so the collision can be resolved before the pipeline relies on it.
- Zero output when the remote is clean; verbose logs help when running with `-Verbose`.
- Used by bundle/export pipelines to guarantee deterministic fetches before cloning fixtures.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Remote` | string | `origin` | Remote to inspect; must be reachable by `git`. |

## Exit Codes
- `0` when no ambiguous refs are detected.
- `!=0` when `git` is unavailable, `ls-remote` fails, or duplicate short names exist.

## Related
- `docs/LABVIEW_GATING.md`
- `tools/Get-BranchProtectionRequiredChecks.ps1`
