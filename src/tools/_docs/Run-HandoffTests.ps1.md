# Run-HandoffTests.ps1

**Path:** `tools/priority/Run-HandoffTests.ps1`

## Synopsis
Execute the Node-based “handoff” test suite (`priority:test`, `hooks:test`, `semver:check`) and emit a JSON summary under `_agent/handoff/test-summary.json`.

## Description
- Finds the local `node` executable and the repo’s `tools/npm/run-script.mjs` wrapper.
- Sequentially runs `node tools/npm/run-script.mjs <script>` for:
  1. `priority:test` (standing priority validation)
  2. `hooks:test` (Git hooks sanity)
  3. `semver:check` (release tagging rules)  
- Captures stdout/stderr, exit codes, start/end timestamps, and writes a summary object (`agent-handoff/test-results@v1`) containing:
  - Overall status (`passed`, `failed`, `error`, or `skipped`)
  - Per-script results array
  - Runner metadata (name, OS, arch, job, image OS/version)
  - Any notes (missing node/wrapper, invocation errors)  
- Fails (`exit 1`) when node/wrapper are missing or any script exits non-zero.

### Parameters
_(none)_

## Exit Codes
- `0` — All scripts passed.
- `1` — Node/wrapper missing or at least one script failed.

## Related
- `tools/priority/bootstrap.ps1`
- `tools/priority/Simulate-Release.ps1`
- `docs/ICON_EDITOR_LAB_SRS.md` (handoff expectations)
