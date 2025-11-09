# Icon Editor Lab – Software Requirements Specification (SRS)
**Document ID:** IELA-SRS • **Version:** 1.0 • **Date:** 2025-11-09

> This SRS is tailored to ISO/IEC/IEEE 29148:2018 and uses **shall**-style, verifiable requirements.
> Sections follow the SRS content guidance in 29148 (Purpose, Scope, Product Perspective, Interfaces,
> Product Functions, Nonfunctional Requirements, Assumptions/Dependencies, and Verification). fileciteturn1file0 fileciteturn1file1

---

## 1 Purpose
Define the capabilities and constraints of the **Icon Editor Lab** automation and reliability tooling
(hosted in this repository) so that stakeholders can build, analyze, compare, and package the Icon Editor
artifacts headlessly and reproducibly on developer machines and CI agents. fileciteturn1file0

## 2 Scope
This SRS covers PowerShell-based tooling, configurations, and test harnesses under `tools/`, `configs/`,
and `tests/` that:
- manage **development mode** for LabVIEW;
- run **VI Analyzer** non-interactively;
- perform **LVCompare**-based VI diffs and render reports;
- stage **snapshots** and build **VIPM packages**; and
- export a **portable bundle** consumed by downstream repos.
It does not specify the VS Code extension or other auxiliary developer UX beyond their CLI interfaces. fileciteturn1file7

## 3 Definitions, Acronyms, Abbreviations
**LVCompare** – LabVIEW VI comparison utility.  
**VI Analyzer** – LabVIEW static analysis tooling.  
**VIPM** – VI Package Manager.  
**Bundle** – Zipped export of lab scripts/configs for downstream consumption.  
Terminology is kept consistent and unambiguous per 29148 language criteria. fileciteturn1file10

## 4 References
- ISO/IEC/IEEE 29148:2018, *Requirements engineering*. (Normative) fileciteturn1file9  
- Repo docs: `docs/LABVIEW_GATING.md`, `docs/LVCOMPARE_LAB_PLAN.md`, `docs/ICON_EDITOR_PACKAGE.md` (Informative).
- Tooling scripts and tests under `tools/` and `tests/` (Informative).
References are separated as required by 29148. fileciteturn1file17

## 5 Product Perspective
This tooling is an element of a larger CI ecosystem. Downstream consumers (e.g., *compare-vi-cli-action*) import the bundle export and invoke the headless flows. Interfaces and constraints are enumerated below per 29148 guidance. fileciteturn1file0

### 5.1 System Interfaces
- LabVIEW (2021/2023/2025) and **LVCompare** executable paths.  
- **VIPM** CLI and dependency bundles (`*.vipc`).  
- Windows process model for pre/post-run **rogue** process detection.  
Interface requirements must be traceable on both sides of the interface. fileciteturn1file12

### 5.2 User Interfaces
Command-line (PowerShell 7+) only; outputs are HTML/Markdown/JSON artifacts intended for CI dashboards. fileciteturn1file0

### 5.3 Hardware Interfaces
None.

### 5.4 Software Interfaces
- LabVIEW CLI / LVCompare; TestStand-based compare harness.  
- VIPM CLI; g-cli as applicable in packaging flows.  
For each interface, message formats and paths are defined by the tool owners and referenced in this SRS. fileciteturn1file19

### 5.5 Communications Interfaces
Local file system; optional Git remote access in repo sync helpers.

### 5.6 Operations
Supports fully unattended operation with environment flags such as `LV_SUPPRESS_UI=1`, `LV_NO_ACTIVATE=1`. Normal operation is headless compare/analyze/package runs; recovery entails closing or killing rogue LabVIEW/LVCompare instances. fileciteturn1file19

### 5.7 Site Adaptation
Paths (e.g., LabVIEW/VIPM locations) and labels are site-configurable via parameters and environment variables. fileciteturn1file19

## 6 Product Functions (Summary)
- Manage **dev mode** lifecycle for LabVIEW.  
- Run **VI Analyzer** headlessly and summarize results.  
- Perform **LVCompare** with timeout and noise-profile controls; render **compare-report.html** and session indices.  
- Generate **fixture** and **snapshot** reports.  
- Build **VIPM** packages and publish artifacts.  
- Export a reusable **bundle** for downstream repos.  
(Detail requirements follow.) fileciteturn1file1

## 7 Constraints
- **OS:** Windows host runners.  
- **PowerShell:** 7.0+.  
- **LabVIEW:** 2021 (PPL builds), 2023 (VIPM packaging), **2025 x64** for LVCompare HTML/reporting flows.  
- **Timeouts:** default **600 s** for warmup and compare stages.  
Constraints bound feasible solutions per 29148. fileciteturn1file13

## 8 Assumptions and Dependencies
- LabVIEW and VIPM are installed and licensed on the host and discoverable by the tooling.  
- Self-hosted runner has permission to spawn/kill LabVIEW/LVCompare processes.  
- Downstream consumers adhere to the bundle’s published structure.  
Assumptions/dependencies are recorded per 29148. fileciteturn1file0

## 9 Specific Requirements
All requirements are **necessary, unambiguous, singular, feasible, and verifiable** per 29148 §5.2.5 and are written in “what, not how” form per §5.2.7. Each requirement includes a verification method. fileciteturn1file13 fileciteturn1file10

### 9.1 Functional Requirements
**IELA-SRS-F-001 (Dev Mode):** The system **shall** enable and disable LabVIEW *development mode* for specified versions and bitness and **shall** verify the resulting state before proceeding with any analyzer or compare action. *Verification:* Test (Pester) + Demonstration.  
**IELA-SRS-F-002 (Rogue Detection):** Before and after any stability iteration or suite run, the system **shall** detect rogue LabVIEW/LVCompare processes and, when requested, **shall** fail the run and emit `rogue-*.json` artifacts. *Verification:* Test + Inspection of artifacts.  
**IELA-SRS-F-003 (VI Analyzer):** Given a `.viancfg`/VI/folder, the system **shall** run VI Analyzer headlessly and **shall** emit an HTML report and a `latest-run.json` summary containing counts of analyzed VIs and test outcomes under `tests/results/_agent/vi-analyzer/<label>/`. *Verification:* Test + Inspection.  
**IELA-SRS-F-004 (VI Compare & Reporting):** Given a base VI and a head VI, the system **shall** run a deterministic LVCompare, apply the requested noise profile, and when `-RenderReport` is set **shall** emit `compare-report.html` plus a `session-index.json` that records inputs, tool paths, and logs under `tests/results/_agent/reports/lvcompare/<label>/`. *Verification:* Test + Inspection.  
**IELA-SRS-F-005 (Fixture & Snapshot Reports):** The system **shall** render Markdown reports for fixture/snapshot descriptions that include file lists and linkable artifacts. *Verification:* Test + Inspection.  
**IELA-SRS-F-006 (VIPM Packaging):** The system **shall** build Icon Editor packages using PPL builds for LabVIEW 2021 (x86/x64) and **shall** package via VIPM using LabVIEW 2023 (x86/x64), emitting versioned `.vip` files. *Verification:* Test + Demonstration.  
**IELA-SRS-F-007 (Bundle Export):** The system **shall** export a portable zip bundle containing `tools/`, `configs/`, and selected `docs/` to `artifacts/icon-editor-lab-tooling.zip`. *Verification:* Demonstration + Inspection.  
**IELA-SRS-F-008 (MissingInProject Suite):** The system **shall** orchestrate the MissingInProject suite, running VI Analyzer before g-cli, and **shall** write a JSON run report per label. *Verification:* Test + Inspection.

### 9.2 Interface & Data Requirements
**IELA-SRS-INT-001 (Snapshot Staging):** The system **shall** stage repo snapshots for compare/analyze flows and **shall** persist a session index with absolute paths and labels. *Verification:* Test + Inspection.  
**IELA-SRS-INT-002 (Environment Flags):** The system **shall** respect headless flags (`LV_SUPPRESS_UI`, `LV_NO_ACTIVATE`) and **shall** set process-local paths (`LABVIEW_PATH`, `LVCOMPARE_PATH`) when provided. *Verification:* Demonstration + Inspection. fileciteturn1file19

### 9.3 Nonfunctional (Quality) Requirements
**IELA-SRS-NF-001 (Reliability):** The system **shall** provide a stability harness that runs *N* iterations (1–20), with pre/post rogue detection and summarized results, to validate dev-mode operations. *Verification:* Test + Analysis.  
**IELA-SRS-NF-002 (Timeouts):** The system **shall** enforce a default **600 s** timeout per LVCompare warmup and compare stage and **shall** support override/disable parameters. *Verification:* Demonstration + Inspection.  
**IELA-SRS-NF-003 (Configurability & Maintainability):** The system **shall** externalize thresholds and filters via JSON schemas (e.g., `configs/icon-editor/vi-diff-heuristics.json`) and **shall** run without hard-coding site paths. *Verification:* Inspection + Analysis. fileciteturn1file1

### 9.4 Verification
Each requirement above is associated with a verification method (Test, Demonstration, Analysis, Inspection) consistent with 29148 guidance and will be qualified using the repo’s Pester suites and emitted artifacts. fileciteturn1file1

---

## 10 Traceability
A Requirements Traceability Matrix (RTM) that maps each requirement to tests, scripts, and expected artifacts is delivered alongside this SRS. Traceability is kept current as scenarios evolve. fileciteturn1file6

