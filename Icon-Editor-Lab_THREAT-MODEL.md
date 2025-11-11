# Icon Editor Lab – Threat Model (lightweight)
_Last updated: 2025-11-09T22:06:22.534959Z_

## Assets
- Source VIs and proprietary IP
- Build/signing tokens (VIPM, repo)
- CI runners (self-hosted Windows)
- Produced artifacts: compare reports, analyzer results, VIPM packages

## Trust Boundaries
- Inputs from Git (PR branches)
- Local/CI filesystem
- External tooling: LabVIEW, LVCompare, VIPM
- PowerShell execution policy and modules

## Attacker Goals
- Inject malicious VIs or paths to exfiltrate data or run code
- Poison compare/analyzer results (tampering)
- Steal tokens (secrets in logs/temp)
- Denial of service via hung LV processes or resource exhaustion

## Controls (mapped)
- Input validation and schema checks (tampering, injection)
- Hashing/signing of outputs (integrity)
- Timeouts, job objects, rogue-process cleanup (availability)
- Least-privilege service account (privilege boundary)
- Script signing and AllSigned (supply chain)
- Structured logs and artifacts (non-repudiation, forensics)

## Residual Risks
- Vendor tool bugs (LVCompare/LabVIEW) -> mitigate by pinning versions, sandboxing, and retries.
- Human error in noise profiles -> mitigate by reviews and determinism checks.
