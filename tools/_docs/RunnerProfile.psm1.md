# RunnerProfile.psm1

**Path:** `tools/RunnerProfile.psm1`

## Synopsis
Utility module that gathers metadata about the current GitHub runner (name, OS, labels, image) for reporting and telemetry.

## Description
- `Get-RunnerProfile` reads environment variables (`RUNNER_NAME`, `RUNNER_OS`, `RUNNER_LABELS`, etc.), resolves runner labels either from env vars or the GitHub REST API (`gh api` fallback to PAT), and caches the results.
- `Get-RunnerLabels` / `Get-RunnerLabelsFromApi` let other scripts reuse the label list without hitting the API repeatedly.
- Used by RunnerInvoker and other scripts to annotate logs and session indices with the runner environment.

## Related
- `tools/RunnerInvoker/RunnerInvoker.psm1`
- GitHub Actions environment variables (`RUNNER_*`, `GITHUB_REPOSITORY`, `GITHUB_RUN_ID`)
