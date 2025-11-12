# RTM (Requirements Traceability Matrix)

| Req | Test | Code | Evidence |
|-----|------|------|----------|
| RQ-0001 | tests/smoke/Smoke.Tests.ps1 | tests/smoke/Smoke.Tests.ps1 | Coverage workflow artifacts (`coverage.xml`, `results.xml`) |
| RQ-0002 | src/tests/tools/RunnerProfile.Utility.Tests.ps1 | src/tools/RunnerProfile.psm1 | PR #33 Cobertura upload (`artifact: cobertura-xml`) |
| RQ-0003 | src/tests/tools/LabVIEWCli.Utility.Tests.ps1 | src/tools/LabVIEWCli.psm1 | Coverage workflow curated suite (Windows runner) |
| RQ-0004 | src/tests/tools/ConsoleWatch.Unit.Tests.ps1 | src/tools/ConsoleWatch.psm1 | PR #32 artifacts + coverage gate |
| RQ-0005 | src/tests/tools/Vipm.Unit.Tests.ps1 | src/tools/Vipm.psm1 | Vipm coverage runs (curated suite artifact set) |
| RQ-0006 | src/tests/tools/GCli.Unit.Tests.ps1 | src/tools/GCli.psm1 | PR #35 GCli coverage (artifact `coverage.xml`, PSSA/ADR gate) |
| RQ-0007 | src/tests/IconEditorPackaging.Smoke.Tests.ps1 (SkipLVCompare integration) | src/tools/icon-editor/Invoke-ValidateLocal.ps1 | Curated coverage run (SkipLVCompare dry-run artifacts: `vi-diff-requests.json`, `vi-comparison-summary.json`, `vi-comparison-report.md`) |
| RQ-0008 | src/tests/Invoke-VIComparisonFromCommit.Tests.ps1 | src/tools/icon-editor/Invoke-VIComparisonFromCommit.ps1 | Curated coverage run (commit overlay artifacts + `stage-log.json` + headless compare log) |

Evidence lookup:
- SkipLVCompare artifacts land under `tests/results/_agent/icon-editor/validate-local-skip` (see `vi-diff-requests.json`, `vi-comparison-summary.json`, `vi-comparison-report.md`).
- Commit overlay artifacts land under `tests/results/_agent/icon-editor/snapshots/commit-<hash>` with `stage-log.json` beside the overlay; the hermetic suite also captures raw compare calls in `TEST_VICOMMIT_COMPARE_LOG`.
