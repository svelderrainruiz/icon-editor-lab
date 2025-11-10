# update_workflows.py

**Path:** `tools/workflows/update_workflows.py`

## Synopsis
Normalize GitHub workflow YAML files so they meet the current icon-editor lab gating, wire-up, and lint/watch policies.

## Description
- Uses `ruamel.yaml` in round-trip mode, preserving comments and formatting while applying scripted transforms.
- Supports two modes:
  - `--check <files...>` — report which workflows need updates (prints `NEEDS UPDATE` and exits 3 if changes would be applied).
  - `--write <files...>` — rewrite each workflow in place and print `updated: <file>`.
- Transforms focus on high-touch workflows such as `pester-selfhosted.yml`, `ci-orchestrated.yml`, `fixture-drift.yml`, `validate.yml`, and smoke/compare workflows. Highlights:
  - Ensure `workflow_dispatch.inputs.force_run` exists and propagate force-run awareness through the `pre-init` job (gated pre-init step, “Compute docs_only” step, wired outputs).
  - Normalize hosted Windows preflight/notice steps so LVCompare checks and runner health diagnostics remain consistent across lint/watch jobs.
  - Inject session-index posts, runner-unblock guards, rerun-hint writers, interactivity probes, and “wire” actions (S1/T1/P1/etc.) where policy requires telemetry coverage.
  - Keep markdown lint non-blocking in validation workflows while still wiring gating jobs to guard actions.
- Designed to be re-runnable: no-op when the workflow already matches repo standards.

### Parameters
| Name | Type | Notes |
| --- | --- | --- |
| `--check <files...>` | CLI option | Evaluate transforms without writing; exit 3 if any file would change. |
| `--write <files...>` | CLI option | Apply transforms to the provided workflow files. |

## Outputs
- Console messages describing files that were updated or still need changes.
- In `--write` mode, overwrites the provided workflow files with normalized YAML.

## Exit Codes
- `0` — All files already compliant or successfully rewritten.
- `2` — Usage error (missing mode/files).
- `3` — `--check` detected files that need updates.

## Related
- `.github/workflows/*.yml`
- `docs/LABVIEW_GATING.md` (policy enforced by these transforms)
