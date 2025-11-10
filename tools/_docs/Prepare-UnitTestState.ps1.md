# Prepare-UnitTestState.ps1

**Path:** `tools/icon-editor/Prepare-UnitTestState.ps1`

## Synopsis
Explains (and optionally checks) the prerequisites required before running icon-editor unit tests.

## Description
- Without flags it prints guidance: enable dev mode, apply VIPM dependencies, and run the Missing-In-Project CLI before kicking off unit suites.
- `-Validate` inspects telemetry under `tests/results/_agent` to confirm those prerequisites were satisfied (dev-mode state, VIPM install logs, MissingInProject CLI results). Throws if any markers are missing.
- Respects `ICON_EDITOR_RESULTS_ROOT` so callers can override where telemetry lives.

### Parameters
| Name | Type | Default |
| --- | --- | --- |
| `Validate` | switch | Off (print instructions only) |

## Outputs
- Console guidance, or validation status/errors when `-Validate` is used.

## Related
- `tools/icon-editor/Invoke-MissingInProjectCLI.ps1`
- `tools/icon-editor/Invoke-VipmDependencies.ps1`
