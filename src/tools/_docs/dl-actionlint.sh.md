# dl-actionlint.sh

**Path:** `tools/dl-actionlint.sh`

## Synopsis
Downloads the `actionlint` binary for the current platform (or a specified version) and places it in the target directory, optionally using GitHub tokens to avoid rate limits.

## Description
- Usage: `bash tools/dl-actionlint.sh [VERSION] [DIR]`
  - `VERSION` defaults to the script’s pinned `1.7.7`; accepts explicit `x.y.z` or `latest`.
  - `DIR` defaults to the current working directory.
- Detects OS/arch (`linux`, `darwin`, `freebsd`, `windows`) and downloads the matching archive from `https://github.com/rhysd/actionlint/releases`.
- Extracts `actionlint` (or `actionlint.exe`) into the target directory and echoes the path.
- When running inside GitHub Actions with `GITHUB_OUTPUT`, writes the executable path as `executable=...`.
- Uses `GH_TOKEN`/`GITHUB_TOKEN` if present to send authenticated requests.

## Exit Codes
- `0` on success.
- Non-zero for invalid arguments, unsupported platforms, or failed downloads.

## Related
- `.github/workflows/*.yml` (actionlint jobs)
