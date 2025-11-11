# Icon Editor Lab – Hardening Pass (v1)
_Last updated: 2025-11-09T22:06:22.534959Z_

This hardening pass targets PowerShell-based automation that runs LabVIEW tooling (LVCompare, VI Analyzer) and VIPM packaging on Windows runners.

## Objectives
- Reduce supply chain and CI risks.
- Improve determinism and failure isolation of headless LabVIEW/LVCompare flows.
- Enforce verifiability and traceability in line with ISO/IEC/IEEE 29148 requirements quality (verifiable, singular, feasible).

## 1) Execution Hardening (PowerShell)
- Set strict modes at the top of every script/module:
  ```powershell
  Set-StrictMode -Version Latest
  $ErrorActionPreference='Stop'
  $PSModuleAutoLoadingPreference='None'
  ```
- CmdletBinding + Parameter validation for all entry points:
  ```powershell
  [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Low')]
  param(
    [Parameter(Mandatory)][ValidateSet('2021','2023','2025')][string]$LabVIEWVersion,
    [Parameter()][ValidateSet(32,64)][int]$Bitness = 64,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$BasePath
  )
  ```
- Quote and validate all paths; reject relative paths that escape workspace (".."), and normalize via Resolve-Path -LiteralPath.
- Time-box external tools. Wrap LVCompare/VI Analyzer with Start-Job + Wait-Job -Timeout and kill process trees if exceeded.
- Guaranteed cleanup using try/finally. Always Stop-Process remaining children and Remove-Item temp dirs.

## 2) Supply Chain & Integrity
- Pin external tool versions: resolve absolute paths to LVCompare/LabVIEW/VIPM; record versions in a session-index.json.
- Hash every produced artifact (SHA-256) and store alongside (.sha256). Verify before consumption.
- Script/code signing: sign .ps1/.psm1 with an org certificate; enforce AllSigned policy in CI with an allowed signer thumbprint list.
- Vendor lockfile: if using PowerShell modules from PSGallery, create requirements.psd1 with exact versions and private gallery mirror.

## 3) Input & Environment Hygiene
- Schema-validate configs (*.json) with Test-Json -SchemaFile before use; fail fast with actionable error.
- Deny by default file types for compare/analyze; ValidateSet / whitelist MIME.
- Sanitize labels used for folder/file names: allow [A-Za-z0-9._-] only; length <= 64.
- Temp/working dirs: always use Join-Path $env:RUNNER_TEMP 'icon-editor-lab' and ensure -Force -Recurse cleanup.

## 4) Robustness, Observability, and D&R
- Structured logging: emit both human logs and machine logs (JSON lines) with timestamps, level, event, fields (inputs, versions, exit codes).
- Retry/backoff for flaky LVCompare/VI Analyzer invocations (max 2 retries; jittered exponential backoff), but never on deterministic failures (schema, not found).
- Rogue-process guardrails: pre/post scans for LabVIEW.* and LVCompare.* with owner PID; kill or fail per policy and record PIDs.
- Resource limits: Job-Object based CPU/memory cap for child processes to protect CI agents.
- Determinism checks: compare two runs of LVCompare on identical inputs; fail if outputs differ (noise profile drift).

## 5) Security Policies
- Least privilege: run comparisons under a dedicated low-privilege service account; no interactive sessions.
- Secrets hygiene: never write secrets to logs; use transcript redaction; scope VIPM tokens to single job; rotate.
- Path traversal & injection: forbid ';', '&', '|', backticks in inputs; use -LiteralPath everywhere.

## 6) Test Strategy (Pester)
- Unit: parameter validation, path handling, timeouts.
- Component: mock LVCompare/VI to simulate exit codes/timeouts; assert cleanup/logging.
- E2E (gated): a small sample pair of VIs; verify report and session index contents plus hashes.

## 7) CI Changes
- Enforce AllSigned execution policy; verify signer.
- Cache LabVIEW/VIPM discoverable paths via job outputs; publish session-index.json and .sha256 artifacts.
- Upload _agent/ JSON logs as CI artifacts; surface summaries in annotations.

## 8) Documentation
- Add SECURITY.md with support window for LabVIEW/VIPM versions and disclosure process.
- Add MAINTENANCE.md with rotation cadence (noise profiles, schema versions, tokens).

---

### Ready-made Snippets

Schema validation gate:
```powershell
$schema = Join-Path $PSScriptRoot 'configs/schema/vi-diff-heuristics.schema.json'
(Get-Content $cfg -Raw) | Test-Json -SchemaFile $schema -ErrorAction Stop
```
Timeout wrapper:
```powershell
$job = Start-Job -ScriptBlock {{ & $LVCompare @args }} -ArgumentList $args
if (-not (Wait-Job $job -Timeout $TimeoutSec)) {{ Stop-Job $job -Force; throw "LVCompare timed out in $TimeoutSec s" }}
$rv = Receive-Job $job -ErrorAction Stop
```
Label sanitizer:
```powershell
if ($Label -notmatch '^[A-Za-z0-9._-]{{1,64}}$') {{ throw "Invalid label: $Label" }}
```
