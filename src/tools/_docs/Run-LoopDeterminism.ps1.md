# Run-LoopDeterminism.ps1

**Path:** `tools/Run-LoopDeterminism.ps1`

## Synopsis
Runs the loop-determinism lint (`tools/Lint-LoopDeterminism.Shim.ps1`) over every workflow in `.github/workflows`, optionally failing on violations.

## Description
- Enumerates all `.yml` files in `.github/workflows`, builds a semicolon-delimited list, and passes it to the shim script.
- `-FailOnViolation` bubbles up to the shim so CI jobs can enforce deterministic loop constraints (usually for TestStand/Compare workflows).

### Parameters
| Name | Type | Default |
| --- | --- | --- |
| `FailOnViolation` | switch | Off |

## Outputs
- Whatever `Lint-LoopDeterminism.Shim.ps1` prints; exit code 0 if lint passes.

## Related
- `tools/Lint-LoopDeterminism.Shim.ps1`
