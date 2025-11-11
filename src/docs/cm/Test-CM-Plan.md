# Configuration Management Plan — Test Work Products
**Document ID:** IELA-CM-TEST-001 • **Status:** Draft rc1 • **Owner:** Release Mgr

## Purpose & Scope
Plan CM for test docs, scripts, reports. ISO 10007 §5.2 planning. :contentReference[oaicite:28]{index=28}

## Configuration Identification (5.3)  :contentReference[oaicite:29]{index=29}
- CIs: `docs/testing/**`, `docs/cm/Test-CM-Plan.md`, `tools/Tests/**`, `TestResults/**`
- Unique naming + versioning; references kept traceable.

## Baselines (5.3.3)  :contentReference[oaicite:30]{index=30}
- Baseline at each RC tag; archive Status/Completion + coverage xml/html.

## Change Control (5.4)  :contentReference[oaicite:31]{index=31}
- PRs require approvals (QA Lead + Release Mgr) for CI/gate changes.

## Status Accounting (5.5) & Reports (5.5.3)  :contentReference[oaicite:32]{index=32}
- Track doc versions, open incidents, coverage trends.

## Configuration Audit (5.6)  :contentReference[oaicite:33]{index=33}
- Check presence of mandatory docs and gate settings per release.
