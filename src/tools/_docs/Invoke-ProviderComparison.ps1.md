# Invoke-ProviderComparison.ps1

**Path:** `tools/Vipm/Invoke-ProviderComparison.ps1`

## Synopsis
Exercises one or more VIPM providers with curated scenarios (InstallVipc, BuildVip, etc.) and logs per-provider telemetry to `tests/results/_agent/vipm-provider-matrix.json`.

## Description
- Accepts inline `-Scenario` objects or a JSON `-ScenarioFile` that describe VIPM operations (`Operation`, `VipcPath`, `VipbPath`, `OutputDirectory`, `Artifacts`, …).  Paths are resolved relative to the repo root so they can live in `configs/vipm-scenarios`.
- For every requested provider (`vipm`, `vipm-gcli`, experimental backends), the script builds the invocation via `Get-VipmInvocation`, runs the external process, captures duration, exit code, warnings, stdout/stderr, and optional artifact hashes, then appends the record to the output JSON.
- Console output prints a concise “VIPM Provider Comparison Summary”, and the function returns the telemetry array so CI jobs can assert pass/fail or upload the JSON artifact.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Providers` | string[] | `@('vipm')` | Provider IDs registered with `tools/Vipm/Vipm.psm1`. |
| `Scenario` | object[] | - | Inline hashtable array describing operations; overrides `ScenarioFile` when supplied. |
| `ScenarioFile` | string | - | Path (absolute or repo-relative) to a JSON array of scenario objects. |
| `OutputPath` | string | `tests/results/_agent/vipm-provider-matrix.json` | Telemetry destination; existing entries are preserved and appended. |
| `SkipMissingProviders` | switch | Off | Suppresses `provider-missing` entries when a provider cannot be resolved. |

## Outputs
- JSON telemetry containing the merged history of provider runs (`Status`, `DurationSeconds`, `Warnings`, `Artifacts`) written to `OutputPath`.
- Console summary lines per provider/scenario pair.

## Exit Codes
- `0` – All requested operations executed (check telemetry for individual failures).
- `!=0` – Script halted before telemetry was written (bad scenario file, provider crash, etc.).

## Related
- `tools/icon-editor/Invoke-VipmDependencies.ps1`
- `tools/Vipm/VipmDependencyHelpers.psm1`
- `docs/LABVIEW_GATING.md`
