# Simulate-Release.ps1

**Path:** `tools/priority/Simulate-Release.ps1`

## Synopsis
Dry-run the standing release workflow: sync the priority router, validate SemVer, surface planned actions, and optionally execute the branch orchestrator.

## Description
- Calls `npm run priority:sync` (via the repo’s Node wrapper) to refresh `tests/results/_agent/issue/router.json`, which drives release actions.
- Runs `tools/priority/validate-semver.mjs` to confirm the current version is valid; writes `tests/results/_agent/handoff/release-summary.json` (`agent-handoff/release-v1`) capturing version, status, and issues.
- Prints the router’s planned actions to stdout and executes any `release:prep` scripts defined there.
- When release steps exist:
  - Default behavior (no flags) runs `tools/Branch-Orchestrator.ps1 -DryRun`.
  - `-Execute` runs with `-Execute`, actually performing branching/push steps.
  - `-DryRun` skips branch orchestrator entirely.
- Throws when SemVer validation fails or required files (router plan, node wrapper) are missing so CI can block tagging.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Execute` | switch | Off | Run Branch-Orchestrator with `-Execute` after release prep. |
| `DryRun` | switch | Off | Skip Branch-Orchestrator even if release actions exist. |

## Outputs
- `tests/results/_agent/handoff/release-summary.json` — SemVer evaluation results.
- Console log of planned actions and release-prep script execution.

## Exit Codes
- `0` — SemVer valid; release simulation completed.
- Non-zero — Node/npm/semver failures, missing router plan, or any prep/orchestrator error.

## Related
- `tools/priority/validate-semver.mjs`
- `tools/Branch-Orchestrator.ps1`
