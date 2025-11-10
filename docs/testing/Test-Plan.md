# Test Plan — tools scope
**Document ID:** IELA-TEST-PLAN-TOOL-001 • **Status:** Draft rc1 • **Owner:** QA Lead
**Approvals:** Eng Mgr / QA Lead • **Change history:** 0.1.0-rc1 seed

## Context (7.2.2)  :contentReference[oaicite:16]{index=16}
- Subject: PowerShell scripts/modules in `tools/`
- Basis: SRS/RTM (if present) + function contracts; repo conventions.

## Assumptions & Constraints (7.2.3)  :contentReference[oaicite:17]{index=17}
- PowerShell 7+; Windows runner in CI; Pester ≥5.4.

## Stakeholders & Comms (7.2.4–7.2.5)  :contentReference[oaicite:18]{index=18}
- QA Lead (owner); Eng Mgr (approver); Devs (contributors). Weekly status note.

## Risk Register (7.2.6)  :contentReference[oaicite:19]{index=19}
| ID | Risk | Prob | Impact | Mitigation |
|----|------|------|--------|------------|
| R1 | Missing `SupportsShouldProcess` | M | H | Add Pester checks; enforce in PR |
| R2 | No Synopsis/help | M | M | Help tests; PR checklist |
| R3 | Parse/load errors | L | H | AST parse gate; self-check script |

## Test Strategy (7.2.7)  :contentReference[oaicite:20]{index=20}
- Techniques: requirements-based; structural coverage; negative/error paths (29119‑1 §4.4). :contentReference[oaicite:21]{index=21}
- Completion criteria: **coverage ≥75%** on `tools/**` (+ 0 failed tests).

## Activities/Estimates, Staffing, Schedule (7.2.8–7.2.10)  :contentReference[oaicite:22]{index=22}
- One sprint to green gates; QA Lead + Dev pair.

## Deliverables
- Status/Completion reports; Pester results + coverage xml; incident log.
