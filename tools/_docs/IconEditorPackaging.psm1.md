# IconEditorPackaging.psm1

**Path:** `icon-editor-lab-8/tools/vendor/IconEditorPackaging.psm1`  
**Hash:** `db3aadceac48`

## Synopsis
Provides a structured setup/main/cleanup flow for packaging the Icon Editor VI.

## Description
Wraps the Modify-VIPB, build_vip, and Close-LabVIEW scripts so every invocation



## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
