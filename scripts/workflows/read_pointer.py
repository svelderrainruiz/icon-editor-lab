#!/usr/bin/env python3
"""Read latest.json pointer and emit GitHub outputs."""

from __future__ import annotations

import json
import os
import sys


def main() -> None:
    if len(sys.argv) < 3:
        raise SystemExit("usage: read_pointer.py <pointer> <output_path>")
    pointer_path, output_path = sys.argv[1:3]
    with open(pointer_path, "r", encoding="utf-8") as handle:
        data = json.load(handle)
    run_root = data.get("run_root") or ""
    timestamp = data.get("timestamp")
    manifest_rel = data.get("manifest_rel") or ""
    manifest_abs = data.get("manifest") or ""
    if not manifest_abs and manifest_rel:
        manifest_abs = os.path.abspath(manifest_rel)
    if not timestamp and run_root:
        timestamp = os.path.basename(run_root.rstrip("/\\"))
    if not timestamp:
        raise SystemExit("Unable to determine Ubuntu run timestamp from pointer.")
    artifact_name = f"ubuntu-local-ci-{timestamp}"
    with open(output_path, "a", encoding="utf-8") as handle:
        handle.write(f"stamp={timestamp}\n")
        handle.write(f"artifact_name={artifact_name}\n")
        if manifest_rel:
            handle.write(f"manifest_rel={manifest_rel}\n")
        if manifest_abs:
            handle.write(f"manifest_abs={manifest_abs}\n")
    print(f"Discovered Ubuntu run stamp {timestamp}")


if __name__ == "__main__":
    main()
