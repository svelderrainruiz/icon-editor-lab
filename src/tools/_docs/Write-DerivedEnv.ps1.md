# Write-DerivedEnv.ps1

**Path:** `tools/Write-DerivedEnv.ps1`

## Synopsis
Capture the derived environment snapshot (via `node tools/npm/run-script.mjs derive:env`) and copy it into `tests/results/_agent/derived-env.json`.

## Description
- Runs the Node wrapper with the `derive:env` script (silent mode). Any errors or stderr are echoed before exiting with the Node exit code.
- Writes the raw JSON (or empty string when derive script produced no output) to `<workspace>/derived-env.json`.
- Ensures `tests/results/_agent/` exists, then copies the file to `tests/results/_agent/derived-env.json` so CI artifacts stay in a consistent location.
- Helpful for debugging environment-derived values (determinism loops, compare toggles) without re-running heavy workflows.

## Outputs
- `<workspace>/derived-env.json`
- `tests/results/_agent/derived-env.json`

## Exit Codes
- `0` — Derive script succeeded and files were written.
- Non-zero — Node wrapper failed; output is printed for troubleshooting.

## Related
- `tools/npm/run-script.mjs`
- `tests/results/_agent/`
