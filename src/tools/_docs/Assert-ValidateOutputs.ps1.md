# Assert-ValidateOutputs.ps1

**Path:** `tools/Assert-ValidateOutputs.ps1`

## Synopsis
Guards the `Validate` stage by asserting that fixture validation JSON, derived environment snapshots, session indexes, and optional delta files exist and contain sane data.

## Description
- Reads `fixture-validation.json` in the current directory, verifies it is non-empty JSON, and confirms it either lists validation items or reports `ok=true`.
- Optional `fixture-validation-delta.json` (when `-RequireDeltaJson`) must be valid JSON; `fixture-summary.md` must have content so the handoff includes human-readable results.
- Derived environment (`<ResultsRoot>/_agent/derived-env.json`) and session index (`<ResultsRoot>/_validate-sessionindex/session-index.json`) are validated for schema markers + non-empty payloads.
- Collects any issues in-memory and exits with a single aggregated error message to keep CI logs succinct.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `ResultsRoot` | string | `tests/results` | Root directory used for derived-env and session-index lookups. |
| `RequireDerivedEnv` | switch | `$true` | When set to `$false`, skips `_agent/derived-env.json` validation. |
| `RequireSessionIndex` | switch | `$true` | Controls whether `_validate-sessionindex/session-index.json` must exist. |
| `RequireFixtureSummary` | switch | `$true` | When disabled, the Markdown summary is not required. |
| `RequireDeltaJson` | switch | `$false` | Enforce presence/validity of `fixture-validation-delta.json`. |

## Outputs
- Writes success/failure to stdout; failures list each missing or malformed artifact.

## Exit Codes
- `0` when every requested artifact exists and passes validation.
- `2` (or general non-zero) when any requirement fails.

## Related
- `docs/LABVIEW_GATING.md`
- `docs/requirements/Icon-Editor-Lab_SRS.md` (`IELA-SRS-F-008` completeness)
