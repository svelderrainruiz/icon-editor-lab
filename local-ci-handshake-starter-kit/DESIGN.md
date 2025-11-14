# Two-way Local CI Handshake (Ubuntu <-> Windows) for LabVIEW Projects

Generated: 2025-11-13T02:51:51Z

This repository contains a complete design + starter kit for a deterministic, file-based handshake where:

- Ubuntu runs first (build/test), computes VI pairs, emits a manifest and requests, then waits.
- Windows (with LabVIEW/LVCompare/TestStand installed) consumes the work, runs only raw comparisons, and publishes a summary pointing to raw outputs.
- Ubuntu detects the Windows summary, ingests raw artifacts, and renders Markdown + HTML final reports.

---

## 1) Directory Layout (Project-relative)

<repo-root>/
  out/
    local-ci-ubuntu/
      <run_id>/
        ubuntu-run.json
        vi-diff-requests.json
        artifacts-ubuntu.zip
        _READY
        windows/
          vi-compare.publish.json
          raw/                    # (optional mirror; Ubuntu may ingest into here)
        reports/
          index.md
          index.html
          assets/
        logs/
        _DONE

    local-ci-windows/
      <run_id>/
        raw/
          session-index.json
          lvcompare/<pair_id>/...
          captures/<pair_id>/...
        logs/
        checksums/sha256sums.txt

Run ID format: YYYYMMDD-HHMMSSZ-<short_commit>-<seq> (e.g., 20251113-142012Z-a1b2c3d-01).

---

## 2) Stages & State Machine

Ubuntu U0 -> U1 -> U2 --READY--> Windows W0 -> W1 -> W2 --PUBLISH--> Ubuntu U3 -> U4 --DONE-->

- U0 Prepare: create run_id, resolve config, clean temp.
- U1 Build/Test: produce optional artifacts-ubuntu.zip; compute VI pairs.
- U2 Publish: write ubuntu-run.json, vi-diff-requests.json, then _READY (atomic sentinel).
- W0 Claim: Windows watcher detects _READY, writes windows.claimed atomically.
- W1 Compare: run LabVIEWCLI/LVCompare per pair -> raw outputs into out/local-ci-windows/<run_id>/raw.
- W2 Publish: write out/local-ci-ubuntu/<run_id>/windows/vi-compare.publish.json (summary pointer).
- U3 Ingest: Ubuntu syncs raw into .../windows/raw and validates checksums.
- U4 Render: Ubuntu renders reports/index.md + index.html; writes _DONE.

Determinism: fixed sort order, pinned versions, content hashes, claim/sentinel files.

---

## 3) JSON Files (Schemas + Examples)

Schemas live in docs/schemas/*.schema.json. Examples in docs/examples/.

- ubuntu-run.json — Ubuntu->Windows manifest
- vi-diff-requests.json — work order with VI pairs
- windows/vi-compare.publish.json — Windows->Ubuntu summary pointer
- raw/session-index.json — Windows-produced per-pair index of outputs

---

## 4) Watchers (Automation Hooks)

Windows watcher
- Monitors out/local-ci-ubuntu/*/_READY
- Claims a run (windows.claimed), runs LVCompare/TestStand
- Writes raw outputs to out/local-ci-windows/<run_id>/raw
- Publishes out/local-ci-ubuntu/<run_id>/windows/vi-compare.publish.json

Ubuntu watcher
- Monitors for windows/vi-compare.publish.json
- Copies/syncs raw from local-ci-windows (or direct) into .../windows/raw/
- Renders Markdown + HTML -> reports/
- Writes _DONE

---

## 5) Config Knobs

See ci-local.yaml: interop location, poll intervals, max parallel pairs, timeouts, tool paths, renderer, retention.

---

## 6) VS Code Tasks

/.vscode/tasks.json starts/stops watchers, runs a single pass, or renders a specific run.

---

## 7) Implementation Notes (LVCompare/TestStand)

- Keep all invocation logic behind tools/windows/RunLVCompare.ps1 which returns a small PSObject per pair.
- If LVCompare cannot emit JSON, ship an adapter that parses logs/HTML and writes a normalized JSON for the renderer.
- Captures (FP/BD) may be generated via a utility VI invoked through LabVIEWCLI; save to captures/<pair_id>/.
- Avoid GUI contention; cap concurrency with max_parallel.

---

## 8) Documentation

Additional docs:
- docs/ARCHITECTURE.md
- docs/SCHEMAS.md
- docs/WATCHERS.md
- docs/COMMANDS.md
- docs/RENDERING.md
- docs/TROUBLESHOOTING.md
- docs/DETERMINISM.md

This folder is a starter kit: ready to drop into your repo and adapt.
