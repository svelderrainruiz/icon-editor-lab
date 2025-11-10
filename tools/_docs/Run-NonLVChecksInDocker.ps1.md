# Run-NonLVChecksInDocker.ps1

**Path:** `tools/Run-NonLVChecksInDocker.ps1`

## Synopsis
Runs the repo’s non-LabVIEW validation checks (actionlint, markdownlint, docs links, workflow drift, dotnet CLI build, priority sync) inside Docker containers to mirror CI behavior.

## Description
- Ensures the Docker CLI is available; resolves shared paths (workspace mount, npm cache, GitHub token) so each container run matches CI.
- Checks can be skipped individually (`-SkipActionlint`, `-SkipMarkdown`, `-SkipDocs`, `-SkipWorkflow`, `-SkipDotnetCliBuild`), and `-FailOnWorkflowDrift` flips the default exit code handling (workflow drift usually exits 3).
- `-UseToolsImage`/`-ToolsImageTag` select a prebuilt “tools” image instead of the default lint/build images; `-PrioritySync` optionally runs the standing-priority sync inside the tools container.
- `-ExcludeWorkflowPaths` lets you omit specific workflow files from the drift check.

### Parameters (subset)
| Name | Type | Notes |
| --- | --- | --- |
| `SkipActionlint`, `SkipMarkdown`, `SkipDocs`, `SkipWorkflow`, `SkipDotnetCliBuild` | switch | Skip individual checks. |
| `FailOnWorkflowDrift` | switch | Treat workflow drift exit code 3 as failure. |
| `PrioritySync` | switch | Run priority sync inside the tools container (requires GH token). |
| `UseToolsImage` | switch | Use `COMPAREVI_TOOLS_IMAGE` (or `-ToolsImageTag`) instead of default images. |
| `ExcludeWorkflowPaths` | string[] | Paths to exclude from drift check. |

## Outputs
- Streams each container’s output; exits with the first failing check’s code. No files are modified locally (apart from build artifacts when dotnet CLI builds run).

## Related
- `.github/workflows/validate.yml`
- `tools/Run-ValidateContainer.ps1`
