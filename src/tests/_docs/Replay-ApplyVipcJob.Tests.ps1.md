# Replay-ApplyVipcJob.Tests.ps1

**Path:** `tests/Replay-ApplyVipcJob.Tests.ps1`

## Synopsis
Tests replay logic for Apply VIPC jobs.

## Description
- Simulates archived VIPC job metadata and ensures the replay script reconstructs the correct command sequence.
- Validates summary JSON includes job identifiers, VIPC path, and outcomes for auditing.
- Ensures missing history files surface warnings rather than silent failures.
- Checks cleanup removes temporary extraction directories when replays complete.

## Run
```powershell
pwsh -File Invoke-PesterTests.ps1 -TestsPath tests/Replay-ApplyVipcJob.Tests.ps1
```

## Tags
- VIPM
- Replay

## Related
- `tools/Replay-ApplyVipcJob.ps1`
