# pre-push.ps1

**Path:** `tools/hooks/scripts/pre-push.ps1`

## Synopsis
Lightweight Git hook that shells into `tools/PrePush-Checks.ps1` before `git push`.

## Description
- Resolves the repo root, prints a banner, and runs `pwsh tools/PrePush-Checks.ps1`.
- If the checks exit non-zero, the hook throws so Git aborts the push.
- Keeps the hook itself minimal so all logic lives in `PrePush-Checks`.

## Exit Codes
- `0` – `PrePush-Checks.ps1` succeeded.
- `!=0` – Checks failed; push aborted.

## Related
- `tools/PrePush-Checks.ps1`
- `.husky/pre-push`
