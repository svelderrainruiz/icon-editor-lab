# Dispatch-WithSample.ps1

**Path:** `tools/Dispatch-WithSample.ps1`

## Synopsis
Uses `gh workflow run` to trigger a GitHub Actions workflow with a freshly generated `sample_id`, plus optional strategy/include flags and extra inputs.

## Description
- Requires an authenticated GitHub CLI (`gh`). Resolves the current repo (prefers `gh repo view`, falls back to `GITHUB_REPOSITORY` or `git remote origin`).
- Generates a unique sample id via `tools/New-SampleId.ps1` and dispatches the requested workflow ID/name/file against `-Ref` (default `develop`).
- Inputs:
  - `include_integration` (`-IncludeIntegration true|false`)
  - `strategy` (`single`|`matrix`)
  - Arbitrary additional inputs via `-ExtraInput name=value`.
- If `gh workflow run` fails (workflow path vs. ID mismatch), falls back to `gh api repos/.../dispatches`.
- Sleeps briefly (`-WaitSeconds`, default 8) then lists the last 15 runs.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Workflow` | string (required) | - | Workflow name, ID, or filename (`.yml`). |
| `Ref` | string | `develop` | Git ref/branch to run against. |
| `IncludeIntegration` | string (`true`/`false`) | - | Sets `include_integration` input. |
| `Strategy` | string (`single`,`matrix`) | `single` | Sets `strategy` input. |
| `ExtraInput` | string[] | - | Additional `-f key=value` pairs passed to `gh workflow run`. |
| `WaitSeconds` | int | `8` | Delay before listing runs. |

## Exit Codes
- `0` when the dispatch request is accepted.
- Non-zero when `gh` is unavailable or the dispatch fails.

## Related
- `tools/New-SampleId.ps1`
- `.github/workflows/ci-orchestrated.yml`
