# CompareVI.Tools.psd1

**Path:** `tools/CompareVI.Tools/CompareVI.Tools.psd1`

## Synopsis
Manifest for the CompareVI helper module that exposes `Invoke-CompareVIHistory` and `Invoke-CompareRefsToTemp`.

## Description
- Declares `CompareVI.Tools.psm1` as the root module (PowerShell 5.1) with version `0.1.0`.
- Limits exports to the two wrapper functions so bundle consumers can `Import-Module tools/CompareVI.Tools` and call them without extra surface area.
- Captures provenance metadata (LabVIEW Community authorship, `compare-vi-cli-action` project URI) for ISO traceability.

## Related
- `tools/CompareVI.Tools/CompareVI.Tools.psm1`
- `tools/Compare-RefsToTemp.ps1`
- `tools/Compare-VIHistory.ps1`
