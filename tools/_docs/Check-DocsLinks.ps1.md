# Check-DocsLinks.ps1

**Path:** `icon-editor-lab-8/tools/Check-DocsLinks.ps1`  
**Hash:** `f5d84f2ad22e`

## Synopsis
Quick link check across Markdown files.

## Description
Scans *.md for links and validates local relative targets exist. Optional HTTP HEAD checks for external links.



## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
