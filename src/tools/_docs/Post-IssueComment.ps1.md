# Post-IssueComment.ps1

**Path:** `tools/Post-IssueComment.ps1`

## Synopsis
Thin wrapper around `gh issue comment` that posts (or edits) a GitHub issue/PR comment from a file or inline body during CI.

## Description
- Validates that GitHub CLI (`gh`) is available, then builds the appropriate command line: `gh issue comment <issue> --body-file <path>` or `--edit-last` when `-EditLast` is specified.
- Supports supplying the comment text via `-BodyFile` (common for generated Markdown) or `-Body` (scripted content). Inline bodies are written to a temp file to satisfy `gh`.
- Optional `-Quiet` suppresses the progress log so callers can keep CI logs minimal.

### Parameters
| Name | Type | Notes |
| --- | --- | --- |
| `Issue` | int (required) | GitHub issue/PR number. |
| `BodyFile` | string | Path to Markdown/text file to post (mutually exclusive with `Body`). |
| `Body` | string | Inline comment content; written to a temp file. |
| `EditLast` | switch | Calls `gh issue comment --edit-last` instead of creating a new comment. |
| `Quiet` | switch | Suppresses informational messages. |

## Exit Codes
- `0` – Comment posted or updated successfully.
- `!=0` – `gh` returned an error; the script throws with the failing exit code.

## Related
- `tools/Publish-VICompareSummary.ps1`
- `.github/workflows/*.yml`
