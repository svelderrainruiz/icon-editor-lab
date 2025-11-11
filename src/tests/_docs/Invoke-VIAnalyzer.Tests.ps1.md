# Invoke-VIAnalyzer.Tests.ps1

**Path:** `tests/Invoke-VIAnalyzer.Tests.ps1`

## Synopsis
Validates the VI Analyzer wrapper around LabVIEW CLI.

## Description
- Mocks LabVIEW CLI invocations to verify analyzer configs and test lists are passed correctly.
- Parses fake analyzer output to ensure pass/fail counts, durations, and result files are recorded.
- Tests timeout and retry behavior plus cleanup actions after analyzer completion.
- Verifies telemetry JSON includes analyzer label, config path, and log references.

## Run
```powershell
pwsh -File Invoke-PesterTests.ps1 -TestsPath tests/Invoke-VIAnalyzer.Tests.ps1
```

## Tags
- VIAnalyzer

## Related
- `tools/Invoke-VIAnalyzer.ps1`
