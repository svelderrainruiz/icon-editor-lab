# Tools.WhatIf.Tests.ps1

**Path:** `tests/tools/Tools.WhatIf.Tests.ps1`

## Synopsis
Ensures scripts honor `-WhatIf` without making changes.

## Description
- Iterates the manifest and invokes each script with `-WhatIf` (and common parameters) to detect unexpected side effects.
- Asserts exit codes remain zero and no files are touched when running in WhatIf mode.
- Collects per-script diagnostics so owners can fix missing ShouldProcess implementations.
- Guards automation from performing destructive actions during dry runs.

## Run
```powershell
pwsh -File Invoke-PesterTests.ps1 -TestsPath tests/tools/Tools.WhatIf.Tests.ps1
```

## Tags
- Meta
- WhatIf

## Related
- `tests/tools/Tools.Loader.ps1`
