# Invoke-VIDiffSweepStrong.Tests.ps1

**Path:** `tests/Invoke-VIDiffSweepStrong.Tests.ps1`

## Synopsis
Covers the "strong" diff sweep variant with duplicate-window/sentinel logic.

## Description
- Exercises duplicate-window mitigation by verifying sentinel TTLs create follow-up runs when needed.
- Validates CLI-suppressed, git-context, and stub modes behave per scenario flags.
- Ensures summary JSON includes sentinel metadata so CI knows why reruns happened.
- Tests optional stub execution path used on hosts without LabVIEW installed.

## Run
```powershell
pwsh -File Invoke-PesterTests.ps1 -TestsPath tests/Invoke-VIDiffSweepStrong.Tests.ps1
```

## Tags
- VICompare
- Sweep

## Related
- `tools/Invoke-VIDiffSweepStrong.ps1`
- `tools/Verify-LocalDiffSession.ps1`
