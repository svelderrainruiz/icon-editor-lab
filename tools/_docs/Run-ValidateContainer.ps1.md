# Run-ValidateContainer.ps1

**Path:** `tools/Run-ValidateContainer.ps1`

## Synopsis
Runs the repo’s “validate” Docker image locally to mirror containerized precheck jobs, capturing logs under `tests/results/_validate-container`.

## Description
- Ensures Docker is available, mounts the current workspace into `/workspace`, and optionally mounts the user’s npm cache to speed up installs.
- Executes `docker run --rm` on the specified image (default `compare-validate`) and streams stdout/stderr to both the console and a timestamped log file.
- Passes through `GITHUB_TOKEN` when available so the container can access private repos.

### Parameters
| Name | Type | Default |
| --- | --- | --- |
| `Image` | string | `compare-validate` | Docker image to run. |
| `Workspace` | string | current directory | Mounted into `/workspace`. |
| `LogDirectory` | string | `tests/results/_validate-container` | Where logs are written. |
| `PassThru` | switch | Off | Return a PSCustomObject with `LogPath`. |

## Outputs
- Console stream and a log file `prechecks-<timestamp>.log` inside `LogDirectory`.
- Throws if the container exits non-zero.

## Related
- `.github/workflows/validate.yml`
