# Demo-FlakyRecovery.ps1

**Path:** `tools/Demo-FlakyRecovery.ps1`

## Synopsis
Runs the Watch-Pester flaky demo to demonstrate automatic retry recovery and produce delta telemetry for training/dev-mode validation.

## Description
- Resets the `tests/results/flaky-demo-state.txt` marker, sets `ENABLE_FLAKY_DEMO=1`, and invokes `tools/Watch-Pester.ps1 -SingleRun` with `-RerunFailedAttempts` (default `2`) and `-Tag FlakyDemo`.
- Writes the Watch delta JSON (`-DeltaJsonPath`, default `tests/results/flaky-demo-delta.json`) plus history at `watch-log.ndjson`.
- Prints status/classification along with recovered attempt counts unless `-Quiet` is specified.
- Warns if the demo run fails to classify as `improved`, signaling other failing tests polluted the demo.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `DeltaJsonPath` | string | `tests/results/flaky-demo-delta.json` | Where to write the Watch delta JSON. |
| `RerunFailedAttempts` | int | `2` | Number of retries Watch should attempt. |
| `Quiet` | switch | Off | Suppress logging; still throws on missing delta output. |

## Outputs
- `tests/results/flaky-demo-delta.json`
- `tests/results/_watch/watch-log.ndjson` (history)

## Exit Codes
- `0` on success; warnings are emitted if classification is not `improved`.
- Non-zero when Watch-Pester or delta generation fails.

## Related
- `tools/Watch-Pester.ps1`
- `docs/LABVIEW_GATING.md`
