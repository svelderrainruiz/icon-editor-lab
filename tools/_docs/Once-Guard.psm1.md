# Once-Guard.psm1

**Path:** `tools/Once-Guard.psm1`

## Synopsis
File-backed guard that ensures an action runs only once per pipeline/workspace by writing marker files under a scope directory.

## Description
- `Invoke-Once -Key <name> -ScopeDirectory <dir> -Action { ... }` checks for `once-<key>.marker` in the scope dir; if absent, runs the action and writes a JSON marker (key + UTC timestamp). Subsequent calls skip the action.
- Used heavily in post-run cleanup (`Post-Run-Cleanup.ps1`) to prevent repeated LabVIEW/LVCompare closures when multiple scripts request them.
- `-WhatIf` evaluates the guard without executing the action.

## Related
- `tools/Post-Run-Cleanup.ps1`
- `docs/LABVIEW_GATING.md`
