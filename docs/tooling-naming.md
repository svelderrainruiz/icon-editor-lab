## Tooling Naming Conventions

We have two CLI entry points that often call into one another when a workflow ultimately launches LabVIEW. The names differentiate the **command surface** (which toggle a workflow is using) rather than who “owns” LabVIEW:

- **`labviewcli`** – refers to the module and providers exposed by `LabVIEWCli.psm1` (PID tracking, CompareVI suppression, etc.). Use this spelling for folders, provider names, documentation, and log output when you call the `labviewcli` command surface.
- **`g-cli`** – refers to the command exposed by `GCli.psm1` and its providers (`gcli/`, `vipm-gcli/`, future `nipm-gcli`). Even though g-cli may spawn LabVIEW under VIPM/NIPM flows, we keep the hyphenated `g-cli` name to highlight that the workflow is entering through the g-cli toolchain.

When adding new modules or providers:

1. Place providers that register the `labviewcli` command under `providers/labviewcli`; providers that wire up `g-cli` belong under `providers/gcli` (or `providers/vipm-gcli` for VIPM-built extensions).
2. Match log strings, documentation, and test names to the command surface in use (`labviewcli` vs `g-cli`). Tests don’t need to know which command eventually starts LabVIEW—only which CLI entry point they are exercising.
3. If a module orchestrates both commands in sequence, call out the hand-off in comments or docstrings, but keep the naming consistent within each section so future diffs stay readable.
