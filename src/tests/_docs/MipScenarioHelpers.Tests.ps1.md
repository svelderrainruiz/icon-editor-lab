# MipScenarioHelpers.Tests.ps1

**Path:** `tests/MipScenarioHelpers.Tests.ps1`

## Synopsis
Tests helper functions that build MIP scenario matrices.

## Description
- Ensures each scenario ID resolves to canonical metadata (LabVIEW version, bitness, gating mode).
- Cross-checks helper output with `docs/LVCOMPARE_LAB_PLAN.md` to avoid drift.
- Validates convenience filters (baseline, fallback, legacy noise profile) behave correctly.
- Confirms unknown scenario IDs throw detailed exceptions used by orchestration scripts.

## Run
```powershell
pwsh -File Invoke-PesterTests.ps1 -TestsPath tests/MipScenarioHelpers.Tests.ps1
```

## Tags
- MIP
- Helpers

## Related
- `docs/LVCOMPARE_LAB_PLAN.md`
- `tools/Invoke-MissingInProjectSuite.ps1`
