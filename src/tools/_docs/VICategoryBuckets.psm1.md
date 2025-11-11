# VICategoryBuckets.psm1

**Path:** `tools/VICategoryBuckets.psm1`

## Synopsis
Map raw VI Compare category strings into normalized slugs, human-readable labels, and higher-level “bucket” classifications (signal/noise/metadata).

## Description
- Defines canonical bucket metadata (e.g., `functional-behavior`, `ui-visual`, `metadata`, `uncategorized`) and per-category definitions (block diagram, connector pane, icon, etc.).
- `Resolve-VICategorySlug -Name <string>` tokenizes an arbitrary category string (from LVCompare JSON) and returns the closest matching slug.
- `Get-VIBucketMetadata -BucketSlug <string>` returns label + classification for buckets.
- `Get-VICategoryMetadata -Name <string>` combines slug resolution with bucket info, giving each category a friendly label, classification, and bucket pointer.
- `ConvertTo-VICategoryDetails -Names <IEnumerable>` normalizes multiple categories, deduplicating by slug and returning metadata objects.
- `Get-VICategoryBuckets -Names <IEnumerable>` returns both detailed category metadata and the unique buckets they map to—used by compare summaries to highlight “signal” vs “noise” diffs.
- Exported functions are pure helpers (no file I/O), making them safe to call in Pester tests or report generators.

## Exports
- `Resolve-VICategorySlug`
- `Get-VIBucketMetadata`
- `Get-VICategoryMetadata`
- `ConvertTo-VICategoryDetails`
- `Get-VICategoryBuckets`

## Related
- `tools/Write-CompareSummaryBlock.ps1`
