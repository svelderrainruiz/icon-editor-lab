# Tools.Help.Tests.ps1

**Path:** `tests/tools/Tools.Help.Tests.ps1`

## Synopsis
Ensures every script listed in tools-manifest exposes `-?` help without errors.

## Description
- Iterates `tests/tools/tools-manifest.json` and launches each entry with `-?` to confirm help loads successfully.
- Verifies help output includes a Synopsis line so docs remain accurate.
- Captures and reports any scripts that exit non-zero when asked for help.
- Guards regressions when new tools are added without appropriate help text.

## Run
```powershell
pwsh -File Invoke-PesterTests.ps1 -TestsPath tests/tools/Tools.Help.Tests.ps1
```

## Tags
- Meta
- Docs

## Related
- `tools/tools-manifest.json`
