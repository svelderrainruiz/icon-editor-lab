# Local CI Handshake Starter Kit

Generated: 2025-11-13T02:51:51Z

## Quick Start (local dev)

1. Place this out/ and tools/ structure inside your repo (or copy the files you need).
2. On Ubuntu:
   ```bash
   # Create a new run (build/test + requests)
   bash tools/ubuntu/run-ci.sh
   # Start Ubuntu watcher (ingest + render)
   bash tools/ubuntu/watch.sh
   ```
3. On Windows:
   ```powershell
   # Start Windows watcher (claim + compare + publish)
   powershell -ExecutionPolicy Bypass -File tools\windows\watch.ps1
   ```

## Manual operations

- Render a specific run on Ubuntu:
  ```bash
  bash tools/ubuntu/render.sh --run <run_id>
  ```

- Process a specific run on Windows:
  ```powershell
  powershell -ExecutionPolicy Bypass -File tools\windows\run-once.ps1 -RunId <run_id>
  ```

## Where files appear

- Ubuntu manifest & requests: out/local-ci-ubuntu/<run_id>/
- Windows raw outputs: out/local-ci-windows/<run_id>/raw/
- Windows summary pointer: out/local-ci-ubuntu/<run_id>/windows/vi-compare.publish.json
- Ubuntu final reports: out/local-ci-ubuntu/<run_id>/reports/

See DESIGN.md for full details.
