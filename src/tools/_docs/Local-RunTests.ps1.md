# Local-RunTests.ps1

**Path:** `tools/Local-RunTests.ps1`

## Synopsis
Runs a curated subset of Pester tests locally (quick/invoker/compare/etc.), disabling CI-only environment toggles.

## Description
- Clears session-lock/STUCK guard env vars, sets `LOCAL_DISPATCHER=1`, and invokes `Invoke-PesterTests.ps1` with the selected profile or custom `-IncludePatterns`.
- Profiles:
  - `quick` (default) – small invoker/compare smoke set
  - `invoker`, `compare`, `fixtures`, `loop`, `full`
- `-IncludeIntegration` switches to integration mode; `-EmitFailuresJsonAlways` mirrors the CI behavior so JSON artifacts are always produced.
- Results are written under `-ResultsPath` (default `tests/results`).

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `IncludePatterns` | string[] | profile-based | Override pattern list. |
| `IncludeIntegration` | switch | Off | Enables integration tests. |
| `Profile` | string | `quick` | Named profile to run. |
| `TestsPath` | string | `tests` | Root fed to `Invoke-PesterTests`. |
| `ResultsPath` | string | `tests/results` | Destination for artifacts. |
| `EmitFailuresJsonAlways` | switch | Off | Forwarded to `Invoke-PesterTests`. |

## Exit Codes
- Same as `Invoke-PesterTests.ps1` (non-zero indicates failing tests).

## Related
- `tools/Invoke-PesterTests.ps1`
