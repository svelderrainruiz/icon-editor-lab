# Lint-Markdown.ps1

**Path:** `tools/Lint-Markdown.ps1`

## Synopsis
Runs `markdownlint-cli2` (or `npx markdownlint-cli2`) against changed or all Markdown files, respecting `.markdownlint.jsonc` and ignore patterns.

## Description
- Determines the repo root, collects Markdown files from `git diff` (merge-base vs `-BaseRef`) unless `-All` is specified, then filters out ignored paths (`.markdownlintignore`, `CHANGELOG.md`, etc.).
- Invokes `markdownlint-cli2` if installed locally, otherwise falls back to `npx --no-install markdownlint-cli2`.
- Treats MD041/MD013 violations as warnings (returns 0) while other rule failures propagate the linter’s exit code.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `All` | switch | Off | Lint every tracked Markdown file. |
| `BaseRef` | string | auto | Git ref used to compute changed files (fallback: `origin/develop`, `HEAD~1`, etc.). |

## Exit Codes
- `0` when lint passes or only “warning” rules (MD041/MD013) are triggered.
- Linter exit code when other rules fail.

## Related
- `.markdownlint.jsonc`
- `.markdownlintignore`
