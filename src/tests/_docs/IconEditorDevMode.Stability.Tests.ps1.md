# IconEditorDevMode.Stability.Tests.ps1

**Path:** `tests/IconEditorDevMode.Stability.Tests.ps1`

## Synopsis
Covers the dev-mode stability harness that opens/closes LabVIEW repeatedly.

## Description
- Exercises the loop logic used by `Test-DevModeStability.ps1`, ensuring iteration counts and required consecutive passes are enforced.
- Intentionally injects simulated LabVIEW failures to confirm retries and backoff reporting are captured in JSON output.
- Verifies rogue sweep data (pre/post) plus `requirements.met` flags are written under `_agent/icon-editor/dev-mode-stability`.
- Asserts env cleanup removes temporary fixtures when the harness aborts early.

## Run
```powershell
pwsh -File Invoke-PesterTests.ps1 -TestsPath tests/IconEditorDevMode.Stability.Tests.ps1
```

## Tags
- IconEditor
- DevMode
- Stability

## Related
- `tools/icon-editor/Test-DevModeStability.ps1`
