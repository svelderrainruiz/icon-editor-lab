# Session-Lock.ps1

**Path:** `tools/Session-Lock.ps1`

## Synopsis
Coordinate exclusive LabVIEW/VIPM runs by acquiring, refreshing, inspecting, or releasing the repository’s file-based session lock.

## Description
- Creates `tests/results/_session_lock/<group>/lock.json` (machine readable) and `status.md` (Markdown summary) to document who owns a lock.
- `-Action Acquire` blocks until the lock is free, respecting `-QueueWaitSeconds` × `-QueueMaxAttempts`. When successful it records workflow metadata, emits `SESSION_LOCK_ID`, `SESSION_LOCK_GROUP`, `SESSION_HEARTBEAT_SECONDS`, and writes GitHub Actions outputs (`status`, `lock_id`, `queue_wait_seconds`). Stale locks older than `-StaleSeconds` trigger either an error (exit 10) or an automatic takeover when `-ForceTakeover` / `SESSION_FORCE_TAKEOVER=1`.
- `Release` removes the lock and status files when the caller owns them (IDs match); mismatched owners result in a no-op but exit 0 so callers can run `Release` in `finally` blocks.
- `Heartbeat` updates `lock.json` with the current timestamp without printing, intended for scheduled jobs that keep long LabVIEW sessions alive.
- `Inspect` prints the current owner information and exits 1 when no lock exists, useful for developers debugging hung locks on self-hosted runners.
- Every parameter can be set explicitly or via environment variables named `SESSION_<PARAM>` (e.g., `SESSION_GROUP`, `SESSION_QUEUE_WAIT_SECONDS`, etc.), enabling reusable GitHub workflows.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Action` | string (required) | — | `Acquire`, `Release`, `Heartbeat`, or `Inspect`. |
| `Group` | string | `pester-selfhosted` | Logical bucket; use distinct groups for compare, dev-mode, VIPM, etc. |
| `QueueWaitSeconds` | int | `15` | Seconds to wait between acquire attempts. |
| `QueueMaxAttempts` | int | `40` | Max retries before timing out (≈10 minutes with defaults). |
| `StaleSeconds` | int | `180` | Lock heartbeat age that counts as stale. |
| `HeartbeatSeconds` | int | `15` | Published for downstream heartbeat schedulers. |
| `ForceTakeover` | switch | Off | Replace stale locks instead of failing. |
| `LockRoot` | string | `tests/results/_session_lock` | Root folder for all lock groups. |

## Outputs
- Files: `tests/results/_session_lock/<group>/lock.json` and `status.md`.
- GitHub Actions outputs for status, lock ID, and queue wait (when acquiring/releasing).
- Environment variables `SESSION_LOCK_ID`, `SESSION_LOCK_GROUP`, `SESSION_HEARTBEAT_SECONDS` on successful acquisition/takeover.

## Exit Codes
- `0` — Requested action succeeded.
- `1` — `Inspect` found no lock.
- `10` — Acquire detected a stale lock and takeover was not allowed.
- `11` — Acquire timed out waiting for an existing lock to release.
- Other non-zero codes bubble up from I/O or unexpected failures.

## Related
- `tools/Trigger-StandingWorkflow.ps1`
- `docs/LABVIEW_GATING.md`
