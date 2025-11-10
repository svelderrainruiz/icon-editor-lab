# Print-PesterTopFailures.ps1

**Path:** `tools/Print-PesterTopFailures.ps1`

## Synopsis
Displays the most recent Pester failures from `tests/results/` (either `pester-failures.json` or `pester-results.xml`) and optionally returns them to the caller.

## Description
- Attempts to read `tests/results/pester-failures.json` first; if missing, falls back to parsing NUnit XML output.
- Prints up to `-Top` failures with command/name, file:line, and the first line of the failure message. Honors console verbosity via `ConsoleUx.psm1`.
- `-PassThru` returns the failure objects so scripts can make decisions; otherwise it only writes summaries to stdout.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `ResultsDir` | string | `tests/results` | Where Pester writes summary artifacts. |
| `Top` | int | `5` | Number of failures to display. |
| `PassThru` | switch | Off | Return failure objects instead of just printing. |
| `ConsoleLevel` | string (`quiet`…`debug`) | from `ConsoleUx` | Controls logging verbosity. |

## Outputs
- Console lines describing the top failures; optional object array when `-PassThru`.

## Related
- `tools/Print-AgentHandoff.ps1`
- `Invoke-PesterTests.ps1`
