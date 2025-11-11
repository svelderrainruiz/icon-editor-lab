# Build-ValidateImage.ps1

**Path:** `tools/docker/Build-ValidateImage.ps1`

## Synopsis
Creates the validation Docker image (default `compare-validate`) using `docker/validate/Dockerfile`.

## Description
- Verifies required CLI tools (currently `docker`) exist; fails early if they are missing.
- Defaults to building `compare-validate` from `docker/validate/Dockerfile`, but both the image name and Dockerfile path can be overridden.
- Determines the build context from the Dockerfile directory, runs `docker build -f <Dockerfile> -t <ImageName> <context>`, and surfaces non-zero exit codes.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `ImageName` | string | `compare-validate` | Docker tag to assign to the resulting image. |
| `Dockerfile` | string | `docker/validate/Dockerfile` | Path to the Dockerfile used for validation image builds. |

## Exit Codes
- `0` when the image builds successfully.
- Non-zero if `docker` is missing, the Dockerfile path is invalid, or the build fails.

## Related
- `tools/Build-ToolsImage.ps1`
- `docker/validate/Dockerfile`
