# ADR 008: Local Integration Reporting for AGENTS

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
- RunnerProfile coverage (RQ-0002 + PR #33) demonstrates instrumentation and CLI-path telemetry feeding integration reports.
- LabVIEWCli coverage (RQ-0003) keeps provider invocation/suppression data hermetic and reportable.
- ConsoleWatch coverage (RQ-0004) validates CI log streaming that powers local integration dashboards.

## Links
- System: `../..` system docs
- Artifacts: `../../artifacts/`
