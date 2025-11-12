# ADR 003: Development Mode Toggle

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
- Development-mode coverage comes from RunnerProfile (RQ-0002) and ConsoleWatch (RQ-0004) tests, which assert the toggle’s effect on instrumentation and console routing.
- Smoke + Sanity suites (RQ-0001 baseline) serve as first-line evidence the toggle doesn’t regress core paths.

## Links
- System: `../..` system docs
- Artifacts: `../../artifacts/`
