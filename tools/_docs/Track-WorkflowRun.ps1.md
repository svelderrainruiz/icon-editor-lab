# Track-WorkflowRun.ps1

**Path:** `icon-editor-lab-8/tools/Track-WorkflowRun.ps1`  
**Hash:** `e2564bca3fca`

## Synopsis
Monitor a GitHub Actions workflow run and display per-job status in real time.

## Description
Polls the GitHub API (via `gh api`) for a given workflow run ID, printing a



## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
