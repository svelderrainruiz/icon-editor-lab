# Get-StandingPriority.ps1

**Path:** `tools/Get-StandingPriority.ps1`

## Synopsis
Retrieves the “standing priority” issue (GitHub label `standing-priority`), honoring overrides and caching, and outputs either JSON or a plain string.

## Description
- Checks for `AGENT_PRIORITY_OVERRIDE` (JSON or `number|title|url` form). When absent, optionally loads a cached copy from `.agent_priority_cache.json`, then queries `gh issue list` for open issues with the `standing-priority` label.
- Maintains `sequence` and `next` hints so rotations follow a defined order.
- Output:
  - Default: JSON object with `number`, `title`, `url`, `source`, `sequence`, etc.
  - `-Plain`: prints `#<number> - <title>` or “Standing priority not set”.
- `-CacheOnly` forces use of the local cache; `-NoCacheUpdate` skips writing updated cache files.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Plain` | switch | Off | Emit human-readable summary instead of JSON. |
| `CacheOnly` | switch | Off | Skip GitHub lookups; rely on cache/override. |
| `NoCacheUpdate` | switch | Off | Prevents writing `.agent_priority_cache.json`. |

## Exit Codes
- `0` when priority data is returned.
- Throws when no priority can be found (no override/cache and GitHub query fails).

## Related
- `.agent_priority_cache.json`
- `tools/Dev-Dashboard.ps1`
