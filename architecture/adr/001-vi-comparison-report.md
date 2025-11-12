# ADR 001: VI Comparison Report

Status: Proposed
Date: 2025-11-10
Decision Owners: TBD

## Context
See System Definition.

## Decision
See ADR text in previous cycle; this RC retains the same decisions.

## Consequences
Traceable evidence expected in artifacts/ once integration runs.

## Evidence
- RTM RQ-0001 references the smoke test baseline and coverage artifacts that validate comparison report scaffolding.
- RunnerProfile (RQ-0002) + LabVIEWCli (RQ-0003) coverage rows provide supporting telemetry for comparison outputs across runners.
- RQ-0007 documents the `Invoke-ValidateLocal` SkipLVCompare dry-run path, exercising the packaging smoke harness and capturing `vi-comparison-summary.json`/`vi-comparison-report.md` artifacts.
- RQ-0008 traces commit-to-commit comparisons via `Invoke-VIComparisonFromCommit`, ensuring overlay staging plus headless compare hooks run deterministically in CI.

## Links
- System: `../..` system docs
- Artifacts: `../../artifacts/`
