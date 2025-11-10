# Run-LocalBackbone.ps1

**Path:** `tools/Run-LocalBackbone.ps1`

## Synopsis
Runs the “local backbone” sequence: optional priority sync, PR VI history compare, Pester/tests, watcher updates, pre-push checks, rogue sweeps, and cleanup—all orchestrated via named steps.

## Description
- Steps are executed via `Invoke-BackboneStep`, which prints banners and respects `-DryRun` to skip execution.
- Features include:
  - Priority sync and scenario setup.
  - `Invoke-PRVIHistory` compare modes with optional LVCompare arguments and failure behavior (`-CompareFailOnDiff`).
  - Pester or `Run-LocalRunTests.ps1` based on `-UseLocalRunTests`/`-SkipPester`.
  - Watcher updates (`Update-SessionIndexWatcher.ps1`), GHA environment checks, `PrePush-Checks.ps1`, LabVIEW cleanup buffer, and `Detect-RogueLV`.
- Flags like `-RunWatcherUpdate`, `-CheckLvEnv`, `-SkipPrePushChecks`, `-DryRun`, `-SkipCompareHistory` let developers tailor the workflow for local triage.

### Parameters (subset)
| Name | Type | Default |
| --- | --- | --- |
| `SkipPrioritySync` | switch | Off |
| `CompareViName` | string[] | - | Limit PR VI history targets. |
| `CompareBranch` | string | `HEAD` |
| `CompareMaxPairs` | int? | - |
| `CompareIncludeMergeParents` / `CompareIncludeIdenticalPairs` | switch | Off |
| `CompareFailOnDiff` | switch | Off |
| `CompareLvCompareArgs` | string | - |
| `CompareResultsDir` | string | - |
| `SkipCompareHistory` | switch | Off |
| `AdditionalScriptPath` | string | - | Optional extra script to run mid-backbone. |
| `IncludeIntegration` | switch | Off | Forwarded to Pester/local tests. |
| `SkipPester`, `UseLocalRunTests` | switch | Off |
| `SkipPrePushChecks` | switch | Off |
| `RunWatcherUpdate` | switch | Off |
| `WatcherJson` | string | - | Required when `RunWatcherUpdate`. |
| `WatcherResultsDir` | string | `tests/results` |
| `CheckLvEnv` | switch | Off |
| `DryRun` | switch | Off |

## Outputs
- Logs for each step under the current console session; artifacts (compare results, watcher JSONs) go to their respective script destinations.

## Related
- `tools/Run-StagedLVCompare.ps1`
- `tools/PrePush-Checks.ps1`
- `tools/Update-SessionIndexWatcher.ps1`
