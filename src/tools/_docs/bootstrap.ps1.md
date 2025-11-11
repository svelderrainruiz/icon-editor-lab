# bootstrap.ps1

**Path:** `tools/priority/bootstrap.ps1`

## Synopsis
Runs the priority hook bootstrap: ensures `develop` is checked out, runs npm hook preflight scripts, syncs the standing snapshot, and records SemVer status for release handoffs.

## Description
- Verifies Node.js is available, then uses `tools/npm/run-script.mjs` to run the various hook npm scripts (`hooks:plane`, `hooks:preflight`, optional `hooks:multi` + `hooks:schema`, `priority:sync`, `priority:show`).
- Ensures the local `develop` branch exists: fetches from `upstream`/`origin`, creates/resets it when missing, or simply checks it out.
- Optionally (unless `-PreflightOnly`) runs the SemVer validator (`tools/priority/validate-semver.mjs`). The results are written to `tests/results/_agent/handoff/release-summary.json` (`agent-handoff/release-v1`) so CI artifacts capture version + validity.
- `-VerboseHooks` adds hook parity/snapshot validation noise but continues even if those scripts fail (`-AllowFailure`).

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `VerboseHooks` | switch | Off | Runs `hooks:multi` + `hooks:schema` and surfaces their output. |
| `PreflightOnly` | switch | Off | Skips the snapshot/priority sync + SemVer validation (only plane + preflight). |

## Outputs
- Log statements for Git/NPM operations.
- `tests/results/_agent/handoff/release-summary.json` describing the latest SemVer check (when not `-PreflightOnly`).

## Exit Codes
- `0` when bootstrap completes (hook scripts may still report issues via warnings).
- Non-zero when git/node prerequisites are missing or npm scripts fail without `-AllowFailure`.

## Related
- `tools/npm/run-script.mjs`
- `tools/priority/validate-semver.mjs`
