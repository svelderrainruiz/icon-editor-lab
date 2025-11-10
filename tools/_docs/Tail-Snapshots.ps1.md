# Tail-Snapshots.ps1

**Path:** `icon-editor-lab-8/tools/Tail-Snapshots.ps1`  
**Hash:** `a82a446eeefe`

## Synopsis
Follow a metrics snapshots NDJSON file produced by -MetricsSnapshotPath and pretty-print selected fields.

## Description
Reads appended JSON lines (schema metrics-snapshot-v2) and displays a rolling table of iteration, diffCount,

```
pwsh -File ./tools/Tail-Snapshots.ps1 -Path snapshots.ndjson
pwsh -File ./tools/Tail-Snapshots.ps1 -Path snapshots.ndjson -PercentileKeys p50,p90,p99
```



## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
