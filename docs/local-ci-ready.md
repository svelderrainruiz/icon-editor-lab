## Local CI Readiness Checklist

Use `tools/Test-LocalCiReadiness.ps1` (or `./local-ci/windows/Invoke-LocalCI.ps1 -Mode Ready`) before pushing changes to make sure the repository satisfies all RC gates.

### What the script checks

1. **Workspace policy** – ensures `$env:WORKSPACE_ROOT` resolves (defaults to `/mnt/data/repo_local`), `.tmp-tests/` exists, the working tree is clean, and `tests/_helpers/Import-ScriptFunctions.ps1` is present.
2. **Pester suites** – runs `Invoke-Pester -Path tests -CI`, emits `artifacts/test-results/results.xml`, and fails when any test fails.
3. **Coverage gates** – validates `artifacts/coverage/coverage.xml` has ≥75% global line-rate and that `src/Core.psm1` / `tools/Build.ps1` (when present) meet the same threshold.
4. **Handshake assets** – ensures `handshake/pointer.json`, `out/local-ci-ubuntu/latest.json`, and the stamped `ubuntu-run.json` exist.
5. **Runner availability (best effort)** – if `python3` and `GITHUB_TOKEN` are available, runs `scripts/workflows/check_windows_runner_coverage.py`; otherwise logs a skip.

The script writes a Markdown table plus `artifacts/local-ci-ready/report.json`. Exit code is non-zero when any required gate fails (unless `-Force` is specified).

### Typical workflow

```pwsh
pwsh tools/Test-LocalCiReadiness.ps1
# or:
./local-ci/windows/Invoke-LocalCI.ps1 -Mode Ready
```

Flags:

- `-SkipTests`, `-SkipCoverage`, `-SkipHandshake`, `-SkipWorkspacePolicy`, `-SkipRunnerCheck` – Skip specific gates (not recommended).
- `-Force` – Record failures but exit 0 (useful when you only want the report file).

### When it fails

Fix the reported gate and rerun the script. For example:

- **Coverage failure** – run `Invoke-Pester -Path tests -CodeCoverage src/Core.psm1` and add more tests.
- **Handshake failure** – re-run the Ubuntu local-ci handshake (`bash local-ci/ubuntu/invoke-local-ci.sh --skip 28-docs --skip 30-tests`).
- **Workspace failure** – clean your working tree or restore missing helpers.

Keeping the readiness script green guarantees the GitHub Actions handshake workflow will pass its initial guards, saving time on the shared Windows runner.
