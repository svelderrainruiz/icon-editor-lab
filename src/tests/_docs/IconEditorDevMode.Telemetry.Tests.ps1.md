# IconEditorDevMode.Telemetry.Tests.ps1

**Path:** `tests/IconEditorDevMode.Telemetry.Tests.ps1`

## Synopsis
Ensures dev-mode enablement emits the expected telemetry artifacts.

## Description
- Builds fake enable/disable runs and inspects `_agent/icon-editor/dev-mode-run/*.json` for schema/version compliance.
- Validates actor, source, timestamps, and rogue summaries are populated even when operations fail.
- Checks that run labels map to scenario IDs used by CI dashboards and rerun hints.
- Confirms HTML/markdown snippets generated for CI step summaries reference the telemetry artifacts created during the test.

## Run
```powershell
pwsh -File Invoke-PesterTests.ps1 -TestsPath tests/IconEditorDevMode.Telemetry.Tests.ps1
```

## Tags
- IconEditor
- DevMode
- Telemetry

## Related
- `tools/icon-editor/Enable-DevMode.ps1`
- `tools/icon-editor/Disable-DevMode.ps1`
