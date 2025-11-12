# ADR 006: Building a VI Package

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
- GCli coverage row in `docs/RTM.md` (RQ-0006) documents `src/tests/tools/GCli.Unit.Tests.ps1` covering `src/tools/GCli.psm1`, with Cobertura outputs from the curated coverage suite (PR #24+ chain).
- ConsoleWatch coverage (RQ-0004) ensures package build monitoring instrumentation is validated via `src/tests/tools/ConsoleWatch.Unit.Tests.ps1`.
- PR #35 (“test(gcli): harden provider import coverage”) refreshed GCli provider import tests and produced passing PR Coverage Gate + Cobertura artifacts for this decision.

## Links
- System: `../..` system docs
- Artifacts: `../../artifacts/`
