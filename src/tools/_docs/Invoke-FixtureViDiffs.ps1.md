# Invoke-FixtureViDiffs.ps1

**Path:** `tools/icon-editor/Invoke-FixtureViDiffs.ps1`

## Synopsis
Stubbed harness used by icon-editor tests to simulate fixture VI compare requests and produce deterministic summary JSON.

## Description
- Reads a JSON request spec (`-RequestsPath`) describing compare pairs, then either logs a dry-run (`-DryRun`) or fabricates capture directories (`pair-###/compare/`) with stub `session-index.json` and `lvcompare-capture.json`.
- Counts totals (`same`, `different`, `dryRun`, etc.) and writes an `icon-editor/vi-diff-summary@v1` file to `-SummaryPath`. Ensures `-CapturesRoot` and summary directories exist before writing.
- Appends a stub log entry to `Global:InvokeValidateLocalStubLog` so higher-level tests can assert that the command was invoked with the expected parameters.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `RequestsPath` | string | *required* | Path to the JSON request descriptor (`requests[]`). |
| `CapturesRoot` | string | *required* | Destination folder for fabricated capture dirs. |
| `SummaryPath` | string | *required* | Where to write `vi-diff-summary@v1`. |
| `DryRun` | switch | Off | Skip capture creation; mark entries as `dry-run`. |
| `TimeoutSeconds`, `CompareScript` | string/int | - | Reserved for future real compare integration (currently unused). |

## Outputs
- `<SummaryPath>` containing `icon-editor/vi-diff-summary@v1`.
- Optional capture directories under `-CapturesRoot` when not in dry-run mode.

## Related
- `tools/icon-editor/Invoke-ValidateLocal.ps1`
- `tests/stubs/Invoke-LVCompare.stub.ps1`
