# Wait-InvokerReady.ps1

**Path:** `tools/RunnerInvoker/Wait-InvokerReady.ps1`

## Synopsis
Pings the RunnerInvoker named pipe until it responds, retrying a configurable number of times.

## Description
- Calls `Invoke-RunnerRequest -Verb Ping` against the invoker pipe at `-PipeName` and `-ResultsDir`. If no `pong` is received, retries up to `-Retries` times, waiting `-RetryDelaySeconds` between attempts.
- Throws when all attempts fail, printing the last error. Useful for workflows that need to confirm the invoker loop has started (`Start-RunnerInvoker`) before sending commands.

### Parameters
| Name | Type | Default |
| --- | --- | --- |
| `PipeName` | string | required | Must match the invoker’s pipe. |
| `ResultsDir` | string | required | Directory where invoker artifacts live. |
| `TimeoutSeconds` | int | 15 | Timeout per ping request. |
| `Retries` | int | 3 | Ping attempts. |
| `RetryDelaySeconds` | int | 2 | Delay between attempts. |

## Related
- `tools/RunnerInvoker/Start-RunnerInvoker.ps1`
- `tools/RunnerInvoker/RunnerInvoker.psm1`
