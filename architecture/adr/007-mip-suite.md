# ADR 007: MIP Suite

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
- MIP suite coverage comes from the combination of RunnerProfile (RQ-0002), LabVIEWCli (RQ-0003), Vipm (RQ-0005), and GCli (RQ-0006) rows, which document the paths exercised and artifacts emitted.
- ConsoleWatch/ConsoleUx coverage (RQ-0004 + curated modules) provide log streaming proof points for MIP telemetry.
- Latest GCli enhancements (PR #35) demonstrate provider import resiliency and are captured in the curated coverage artifacts referenced by RQ-0006.

## Links
- System: `../..` system docs
- Artifacts: `../../artifacts/`
