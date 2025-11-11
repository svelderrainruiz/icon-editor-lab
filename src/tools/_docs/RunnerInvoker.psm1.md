# RunnerInvoker.psm1

**Path:** `tools/RunnerInvoker/RunnerInvoker.psm1`

## Synopsis
Modular invoker for local automation “planes” (running CompareVI, staging LVCompare, watchdog updates, etc.) that manages child-process tracking, single-compare state, and JSON logging.

## Description
- Provides helpers that RunnerInvoker scripts call to handle invoke requests (compare VI, run TestStand staging, update watchers, run DX suites, etc.). Each handler logs stdout/stderr, captures leak warnings, and records artifacts under `tests/results`.
- Includes utility functions for spawns tracking (`Append-Spawns`), single compare gating (`Get/Set-SingleCompareState`), process persistence logs, JSON read/write helpers, and environment resolution.
- The module is consumed by the `tools/RunnerInvoker/*.ps1` entrypoints (Start, Wait, Session lock) so local runs mimic CI’s invoker plane.

## Related
- `tools/RunnerInvoker/Start-RunnerInvoker.ps1`
- `tools/RunnerInvoker/Wait-InvokerReady.ps1`
- `tools/RunnerInvoker/RunnerProfile.psm1`
