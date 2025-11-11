# Tools.ShouldProcess.Help.Tests.ps1

**Path:** `tests/tools/Tools.ShouldProcess.Help.Tests.ps1`

## Synopsis
Verifies that ShouldProcess-enabled scripts provide help text explaining -WhatIf/-Confirm usage.

## Description
- Uses Tools.Loader to detect scripts marked with `SupportsShouldProcess`.
- Invokes `-?` and asserts help output mentions WhatIf/Confirm semantics.
- Flags any script that gained ShouldProcess but lacks documentation updates.
- Helps keep automation safe by ensuring destructive operations advertise confirmation switches.

## Run
```powershell
pwsh -File Invoke-PesterTests.ps1 -TestsPath tests/tools/Tools.ShouldProcess.Help.Tests.ps1
```

## Tags
- Meta
- ShouldProcess

## Related
- `tests/tools/Tools.Loader.ps1`
