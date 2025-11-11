# Build-ToolsImage.ps1

**Path:** `tools/Build-ToolsImage.ps1`

## Synopsis
Builds the local Docker image (`tools/docker/Dockerfile.tools`) that packages CompareVI tooling and dependencies.

## Description
- Resolves the repo root (using `git rev-parse --show-toplevel` fallback) and points Docker at `tools/docker/Dockerfile.tools`.
- Runs `docker build -f ... -t <Tag> <repoRoot>`; when `-NoCache` is set the build uses `--no-cache` to avoid layer reuse.
- Emits the full docker command before execution and fails if the build exits non-zero.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Tag` | string | `comparevi-tools:local` | Name:tag applied to the resulting image. |
| `NoCache` | switch | Off | Adds `--no-cache` to the build for clean rebuilds. |

## Exit Codes
- `0` when Docker build succeeds.
- Non-zero when the Dockerfile is missing or `docker build` fails.

## Related
- `tools/docker/Dockerfile.tools`
- `tools/docker/Build-ValidateImage.ps1`
