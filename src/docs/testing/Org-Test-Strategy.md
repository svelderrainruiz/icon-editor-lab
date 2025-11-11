# Organizational Test Strategy
**Document ID:** IELA-TEST-STR-001 • **Status:** Draft rc1
**Approval:** Eng Mgr / QA Lead • **Change history:** 0.1.0-rc1

## Scope
Applies to **tools** folder and exported functions. Strategy content per 29119-3 §6.3. :contentReference[oaicite:11]{index=11}

## Risk Management (generic)
- Maintain **risk register** in Test Plan; prioritize tests by risk. (29119‑1 §4.2). :contentReference[oaicite:12]{index=12}

## Test Selection & Prioritization
- Focus on: `SupportsShouldProcess`, `-WhatIf`, **help Synopsis**, parse/load hygiene.

## Documentation & Reporting
- Deliver Status (7.3) each sprint; Completion (7.4) per RC. :contentReference[oaicite:13]{index=13}

## Automation & Tools
- **Pester v5**; CI on PRs; artifacts under `TestResults/`.

## CM of Test Work Products
- Test docs/reports are **configuration items**; baseline per ISO 10007 §5.3.3; change control §5.4; status accounting §5.5; audits §5.6. :contentReference[oaicite:14]{index=14}

## Levels/Types & Completion Criteria
- Component/System (PowerShell functions); completion ≥75% coverage of `tools/**`. (Plan details §7.2.10). :contentReference[oaicite:15]{index=15}
