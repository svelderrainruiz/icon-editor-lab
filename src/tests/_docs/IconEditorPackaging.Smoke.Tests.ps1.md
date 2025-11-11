# IconEditorPackaging.Smoke.Tests.ps1

**Path:** `tests/IconEditorPackaging.Smoke.Tests.ps1`

## Synopsis
Smoke-tests the packaging pipeline from VIP outputs through manifest validation.

## Description
- Runs the packaging workflow end-to-end inside Pester to ensure VIPs can be generated from fixtures.
- Checks both x86 and x64 lvlibp payloads exist in the nested VIP and reports accurate statuses.
- Validates package-smoke summary JSON fields (status, vipCount, items[*]) and failure hints.
- Ensures transcripts/logs are placed under `tests/results` for CI artifact pickup.

## Run
```powershell
pwsh -File Invoke-PesterTests.ps1 -TestsPath tests/IconEditorPackaging.Smoke.Tests.ps1
```

## Tags
- Packaging
- Smoke

## Related
- `tools/icon-editor/Test-IconEditorPackage.ps1`
- `tools/icon-editor/Simulate-IconEditorBuild.ps1`
