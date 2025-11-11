# Invoke-MissingInProjectSuite.Tests.ps1

**Path:** `tests/Invoke-MissingInProjectSuite.Tests.ps1`

## Synopsis
Full-suite coverage for Missing In Project orchestration.

## Description
- Simulates suite orchestration from fixture staging through compare + report generation.
- Validates scenario metadata (IDs 1–6b) is recorded alongside session-index outputs.
- Ensures HTML/JSON attachments are zipped for CI publishing even on failures.
- Checks rerun hints and telemetry summaries reference the correct suite label and warmup mode.

## Run
```powershell
pwsh -File Invoke-PesterTests.ps1 -TestsPath tests/Invoke-MissingInProjectSuite.Tests.ps1
```

## Tags
- MIP
- Suite

## Related
- `tools/Invoke-MissingInProjectSuite.ps1`
