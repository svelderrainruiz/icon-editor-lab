# Check-WorkflowDrift.ps1

**Path:** `tools/Check-WorkflowDrift.ps1`

## Synopsis
Verifies that tracked GitHub Actions workflows match the auto-generated versions produced by `tools/workflows/update_workflows.py`, optionally applying and staging fixes.

## Description
- Resolves a local `python`/`py` executable and installs `ruamel.yaml` (user scope) so the update script can run identically to CI.
- Targets a fixed set of workflow files (pester/selfhosted, fixture drift, orchestration, etc.). When `-AutoFix` is set, runs the Python helper with `--write` to refresh the YAML before performing the mandatory `--check`.
- Prints diff stats when drift occurs and can stage + commit the changes automatically (`-Stage`, `-CommitMessage`).
- Returns success (exit 0) for both “no drift” and “drift fixed and staged” scenarios; other error codes bubble from the Python helper.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `AutoFix` | switch | Off | Runs the updater in `--write` mode before the drift check. |
| `Stage` | switch | Off | After a successful fix, `git add` the touched workflow files. |
| `CommitMessage` | string | - | When provided (and `-Stage` or `git add` succeeded), auto-commit the staged files if no extra files are staged. |

## Exit Codes
- `0` when workflows match or when drift is fixed/staged successfully.
- `3` is treated as “drift fixed” by the script (still exits 0 after staging).
- Other values mirror the Python updater's exit code (e.g., syntax errors).

## Related
- `tools/workflows/update_workflows.py`
- `.github/workflows/*.yml`
