# Tools.Loader.ps1

**Path:** `tests/tools/Tools.Loader.ps1`

## Synopsis
Utility loader shared by the tools meta-tests.

## Description
- Provides helper functions to resolve script paths from the manifest and build standardized command lines.
- Exposes execution helpers that capture stdout/stderr for assertion inside meta-tests.
- Centralizes logic for skipping scripts on unsupported platforms.
- Ensures meta-tests remain small by reusing the loader across WhatIf/Help suites.

## Run
```powershell
pwsh -File Invoke-PesterTests.ps1 -TestsPath tests/tools/Tools.Loader.ps1
```

## Tags
- Meta
- Loader

## Related
- `tests/tools/Tools.Help.Tests.ps1`
- `tests/tools/Tools.ShouldProcess.Help.Tests.ps1`
- `tests/tools/Tools.WhatIf.Tests.ps1`
