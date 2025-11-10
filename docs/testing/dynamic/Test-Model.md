# Test Model Specification (8.2)  :contentReference[oaicite:25]{index=25}
**ID:** IELA-TM-TOOLS-001 • **Objective:** Verify CLI hygiene of exported functions
**Coverage items:** 
- Presence of `CmdletBinding(SupportsShouldProcess=$true)` for mutators
- `-WhatIf` non-throw on non-mandatory paths
- `Get-Help` **Synopsis** non-empty
- Parse OK for *.ps1/*.psm1
