# Icon Editor Lab Tooling Provider

This document defines how `icon-editor-lab` serves as a _versioned tooling
provider_ for sibling repositories such as `labview-icon-editor` and
`compare-vi-cli-action`.

The goal is to keep cross‑repo CI behavior aligned (SemVer checks, VI compare
contracts, local CI harnesses) while avoiding hard runtime dependencies on this
repository.

## Versioning model

- **Source of truth** – Tags in `icon-editor-lab` (for example, `v0.2.0`) are
  the canonical reference for the tooling state.
- **Bundles** – Tooling is exported via self‑contained bundles that embed:
  - A manifest with the source commit SHA, bundle schema, and file checksums.
  - All scripts/docs needed for a specific concern (SemVer guard, local‑CI
    handshake, VI compare contract).
- **Consumption** – Other repos either:
  - Copy the bundle contents into their tree (committing them as first‑class
    files), or
  - Reference a published bundle artifact/release created from this repo.

## SemVer guard bundle

SemVer validation is provided via the `Export-SemverBundle.ps1` tooling:

- **Export**:

  ```powershell
  pwsh -File tools/Export-SemverBundle.ps1 `
    -IncludeWorkflow `
    -TargetRepoRoot C:\path\to\target-repo
  ```

- **Contents**:
  - `src/tools/priority/validate-semver.mjs`
  - SemVer docs (`docs/semver-guard-kit.md`, `docs/semver-node-evidence.md`,
    `docs/semver-release-checklist.md`)
  - Optional `.github/workflows/semver-guard.yml`
  - `bundle.json` capturing the source commit and SHA256 hashes.

- **Consumers**:
  - `compare-vi-cli-action` uses this bundle to define `npm run semver:check`
    and the SemVer guard workflow.
  - `labview-icon-editor` can consume the same bundle to keep release tags
    aligned with this repo.

## Local CI handshake starter kit

The local CI handshake (Ubuntu → Windows → Ubuntu) is exported as a starter
kit:

- **Artifacts**:
  - `local-ci-handshake-starter-kit.zip` – generated and updated from this
    repo; contains:
    - `local-ci/ubuntu/` shell runner + stages.
    - `local-ci/windows/` PowerShell runner + stages.
    - `.github/workflows/local-ci-handshake.yml` template.
    - Docs explaining `ubuntu-run.json`, pointer JSON, and artifact layout.

- **Usage**:
  - Downstream repos can unzip the starter kit into their tree and adjust:
    - Runner labels (`runs-on`),
    - Stage paths,
    - Profile toggles (`local-ci/windows/profile.psd1`).
  - The handshake contract (paths under `out/local-ci-ubuntu/` and the pointer
    file) remains consistent, so this repo can always ingest their artifacts for
    debugging.

## VI compare contract

The VI compare contract (for fixture requests and publish summaries) is defined
here:

- **Requests**:
  - Schema: `icon-editor/vi-diff-requests@v1`
  - Example: `out/local-ci-ubuntu/<stamp>/vi-comparison/vi-diff-requests.json`
  - Fields: `name`, `relPath`, `category`, and optional baseline/candidate
    descriptors.

- **Publish summaries**:
  - Schema: `vi-compare/publish@v1`
  - Producer (Windows; e.g., `labview-icon-editor` or this repo) writes:
    - `ubuntuPayload` – originating Ubuntu run stamp or label.
    - `windowsRun` – Windows run stamp.
    - `paths` – where to find `vi-comparison-summary.json` and rendered
      reports.
  - Consumer (Ubuntu; Stage 45 in this repo) reads the publish JSON, copies the
    real captures into the current run, and re-renders Markdown + HTML.

- **Export**:
  - The contract is implemented by:
    - `local-ci/windows/scripts/Invoke-ViCompareLabVIEWCli.ps1`
    - `local-ci/ubuntu/stages/45-vi-compare.sh`
    - `src/tools/icon-editor/Invoke-FixtureViDiffs.ps1`
    - `src/tools/icon-editor/Render-ViComparisonReport.ps1`
  - Downstream repos can either:
    - Copy these scripts verbatim, or
    - Treat them as reference implementations and adapt paths as needed.

## Provisioning & runners

For self‑hosted Windows runners, this repo provides:

- `local-ci/windows/scripts/Provision-LocalRunner.ps1` – installs PowerShell 7,
  Node.js 20 LTS, Python 3.11+, Pester/ThreadJob, and optionally imports the
  signing certificate using winget or Chocolatey.
  - `docs/local-ci-runner.md` – describes the hardware/software baseline,
  recommended labels (for example `[self-hosted, Windows, X64]`), and
  environment toggles used by the local CI handshake.

Downstream repos depend on these only as **versioned tooling**: They can copy
the script/docs at a specific `icon-editor-lab` tag and run them locally
without requiring a live dependency on this repository.
