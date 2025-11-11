# Binding-MinRepro.ps1

**Path:** `tools/Binding-MinRepro.ps1`

## Synopsis
Minimal deterministic harness for parameter-binding tests; emits predictable `[repro]` output whether `-Path` resolves or not.

## Description
- When `-Path` is omitted or points to a non-existent file, writes a single `[repro] ...` line (warning suppressed) so Pester assertions can `Should -Match` without brittle indexing.
- When a valid path is supplied, dumps the raw args, `PSBoundParameters` keys, and the resolved path; optional verbose diagnostics add PSVersion, host, loaded modules, and profile info to help reproduce binding issues.
- `-VerboseDiagnostics` can also be toggled via `BINDING_MINREPRO_VERBOSE=1` to avoid editing tests.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Path` | string | *none* | File path being tested; missing/invalid paths still produce deterministic output. |
| `VerboseDiagnostics` | switch | Off | Adds environment context (PSVersion, modules, profiles); also enabled via `BINDING_MINREPRO_VERBOSE`. |

## Outputs
- `[repro] ...` lines suitable for `Should -Match`; warnings are suppressed to keep a single line when the path is missing/invalid.

## Exit Codes
- `0` unless an unexpected exception occurs.

## Related
- `tests/Binding-MinRepro.Tests.ps1`
