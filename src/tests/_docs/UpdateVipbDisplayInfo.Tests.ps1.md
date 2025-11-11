# UpdateVipbDisplayInfo.Tests.ps1

**Path:** `tests/UpdateVipbDisplayInfo.Tests.ps1`

## Synopsis
Covers the VIPB display info updater.

## Description
- Uses sample VIPB projects to ensure display metadata (names, descriptions, icons) is rewritten correctly.
- Validates compatibility fields and keyword lists persist after updates.
- Ensures schema mismatches produce descriptive warnings rather than silent failures.
- Confirms backup files are created/deleted according to script settings.

## Run
```powershell
pwsh -File Invoke-PesterTests.ps1 -TestsPath tests/UpdateVipbDisplayInfo.Tests.ps1
```

## Tags
- VIPM
- Metadata

## Related
- `tools/UpdateVipbDisplayInfo.ps1`
