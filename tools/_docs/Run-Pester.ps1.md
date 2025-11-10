# Run-Pester.ps1

**Path:** `tools/Run-Pester.ps1`

## Synopsis
Installs (if needed) and runs the repo’s Pester test suite, producing NUnit XML and summary text under `tests/results`.

## Description
- Resolves the target Pester version (default `5.7.1`, overridable via `tools/Get-PesterVersion.ps1` or `PESTER_VERSION`), installs it under `tools/modules` when missing, and imports it.
- Configures Pester 5 to execute `tests/`, excluding `Integration` tags unless `-IncludeIntegration` is supplied. Results are written to `tests/results/pester-results.xml`.
- After the run, emits a brief summary (`pester-summary.txt`) and exits non-zero if there are failures/errors, making it safe for CI gating.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `IncludeIntegration` | switch | Off | When set, integration-tagged tests are included. |

## Outputs
- `tests/results/pester-results.xml` (NUnit) and `tests/results/pester-summary.txt`.

## Related
- `tools/Print-PesterTopFailures.ps1`
- `tests/README.md`
