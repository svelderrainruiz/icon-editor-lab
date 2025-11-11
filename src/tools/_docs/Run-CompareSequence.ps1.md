# Run-CompareSequence.ps1

**Path:** `tools/Run-CompareSequence.ps1`

## Synopsis
Runs a local end-to-end LVCompare sequence (Compare ➜ Verify ➜ Render ➜ Telemetry) against a specific base/head VI pair, writing artifacts under `results/<seqId>`.

## Description
- Creates a sequence ID (timestamp if not provided) and uses a filesystem lock to avoid concurrent runs inside the same `results/<seqId>` folder.
- Steps:
  1. **Compare** – Calls `scripts/CompareVI.psm1` to produce `compare-exec.json`.
  2. **Verify** (optional `-Verify`) – Executes `tools/Verify-FixtureCompare.ps1` to validate fixture captures.
  3. **Render** (optional `-Render`) – Generates `compare-report.html` via `scripts/Render-CompareReport.ps1`.
  4. **Telemetry** (optional `-Telemetry`) – Runs `tools/Detect-RogueLV.ps1` and stores `rogue-lv-detection.json`.
- Designed for local debugging of LVCompare flows without invoking the full dispatcher; all artifacts land under `results/<seqId>` for easy inspection.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Base` | string | - | Path to base VI; required when running compare. |
| `Head` | string | - | Path to head VI. |
| `SeqId` | string | timestamp | Destination folder name under `results/`. |
| `Verify` | switch | Off | Run fixture verification phase. |
| `Render` | switch | Off | Produce HTML compare report. |
| `Telemetry` | switch | Off | Capture rogue-process telemetry after the run. |

## Outputs
- `results/<seqId>/compare-exec.json`, optional `compare-report.html`, verification outputs, and telemetry JSON.
- Console logs like `[seq:<id>] Compare -> ...`.

## Related
- `scripts/CompareVI.psm1`
- `tools/Verify-FixtureCompare.ps1`
- `scripts/Render-CompareReport.ps1`
