# Tick.psm1

**Path:** `tools/Timing/Tick.psm1`

## Synopsis
Minimal stopwatch helpers (`Start/Wait/Read/Stop`) for scripts that need coarse millisecond timing or tick counts.

## Description
- `Start-TickCounter [-TickMilliseconds <int>]` spawns a `System.Diagnostics.Stopwatch`, starts it immediately, and tracks the desired tick interval (default 1 ms).
- `Wait-Tick -Counter <obj> [-Milliseconds <int>]` sleeps for the requested interval and increments the counter’s `ticks` property; returns the counter for chaining.
- `Read-TickCounter -Counter <obj>` reports `ticks`, `elapsedMs` (rounded to three decimals), and the original interval.
- `Stop-TickCounter -Counter <obj>` stops the underlying stopwatch if still running.
- Frequently used in local compare utilities to coordinate sentinel TTLs or throttle loops without relying on complex scheduling libraries.

## Exports
- `Start-TickCounter`
- `Wait-Tick`
- `Read-TickCounter`
- `Stop-TickCounter`

## Related
- `tools/Verify-LocalDiffSession.ps1`
