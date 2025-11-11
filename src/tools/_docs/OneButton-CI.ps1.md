# OneButton-CI.ps1

**Path:** `tools/OneButton-CI.ps1`

## Synopsis
Triggers the Validate and CI-Orchestrated workflows (one after another), waits for completion, downloads key artifacts, and writes a consolidated report under `_onebutton/`.

## Description
- Uses GitHub CLI (`gh workflow run`) to dispatch:
  1. Validate workflow (optionally container-based).
  2. CI-Orchestrated workflow with `strategy=single` and `include_integration=true` (unless `-IncludeIntegration` overrides).
- Waits for each run to complete, downloads artifacts, and summarizes results in `tests/results/_onebutton/`.
- `-AutoOpen` attempts to open the resulting summary in the default viewer; `-UseContainerValidate` and `-SkipRemoteValidate` control which workflows run.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Ref` | string | current branch or `develop` | Target ref for both workflows. |
| `IncludeIntegration` | string (`true`,`false`) | `true` | Input passed to CI-Orchestrated. |
| `Strategy` | string (`single`,`matrix`) | `single` | Orchestrated strategy input. |
| `AutoOpen` | switch | Off | Opens the local summary after completion. |
| `UseContainerValidate` | switch | Off | Dispatches the container-based validate workflow. |
| `SkipRemoteValidate` | switch | Off | Skip the remote validate dispatch (only run CI orchestrated). |

## Exit Codes
- Non-zero when either workflow fails or artifact processing encounters a fatal error.

## Related
- `tools/Watch-RunAndTrack.ps1`
- `tools/Watch-OrchestratedRest.ps1`
