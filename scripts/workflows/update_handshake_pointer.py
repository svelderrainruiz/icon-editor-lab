#!/usr/bin/env python3
"""Create or update the GitHub handshake pointer JSON."""

from __future__ import annotations

import argparse
import json
import os
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pointer", required=True, help="Path to pointer JSON.")
    parser.add_argument("--stamp", help="Ubuntu stamp (write step).")
    parser.add_argument("--artifact", help="Ubuntu artifact name.")
    parser.add_argument("--manifest-rel", help="Relative path to ubuntu-run.json.")
    parser.add_argument("--manifest-abs", help="Absolute path to ubuntu-run.json.")
    parser.add_argument("--ubuntu-pointer", help="Path to latest.json pointer.")
    parser.add_argument("--windows-run", help="Absolute Windows run root.")
    parser.add_argument("--windows-runner", help="Windows runner name.")
    parser.add_argument("--windows-job", help="GitHub run id for Windows job.")
    return parser.parse_args()


def load_pointer(path: Path) -> dict:
    if not path.exists():
        return {}
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def write_pointer(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".tmp")
    with tmp.open("w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2)
        handle.write("\n")
    tmp.replace(path)


def update_for_ubuntu(
    pointer: dict,
    stamp: str,
    artifact: str,
    manifest_rel: Optional[str],
    manifest_abs: Optional[str],
    ubuntu_pointer: Optional[str],
) -> dict:
    now = datetime.now(timezone.utc).isoformat()
    payload = {
        "schema": pointer.get("schema") or "handshake/v1",
        "sequence": int(time.time()),
        "status": "ubuntu-ready",
        "last_updated": now,
        "ubuntu": {
            "stamp": stamp,
            "artifact": artifact,
            "manifest_rel": manifest_rel or None,
            "manifest_abs": manifest_abs or None,
            "pointer": ubuntu_pointer or None,
            "updated_at": now,
        },
        "windows": pointer.get("windows") or {"status": "pending", "updated_at": None},
    }
    return payload


def update_for_windows(
    pointer: dict,
    run_root: Optional[str],
    runner: Optional[str],
    job_id: Optional[str],
) -> dict:
    now = datetime.now(timezone.utc).isoformat()
    existing_sequence = pointer.get("sequence") or 0
    pointer["sequence"] = existing_sequence + 1
    pointer["last_updated"] = now
    windows = pointer.setdefault("windows", {})
    if run_root:
        pointer["status"] = "windows-ack"
        windows["status"] = "imported"
        windows["run_root"] = run_root
        windows["stamp"] = os.path.basename(run_root.rstrip("/\\")) or run_root
    else:
        pointer["status"] = "ubuntu-ready"
        windows["status"] = "pending"
        windows["run_root"] = None
        windows["stamp"] = None
    windows["runner"] = runner
    windows["updated_at"] = now
    if job_id is not None:
        windows["job"] = job_id
    return pointer


def main() -> None:
    args = parse_args()
    path = Path(args.pointer)
    pointer = load_pointer(path)
    if args.stamp:
        pointer = update_for_ubuntu(
            pointer,
            stamp=args.stamp,
            artifact=args.artifact or "",
            manifest_rel=args.manifest_rel,
            manifest_abs=args.manifest_abs,
            ubuntu_pointer=args.ubuntu_pointer,
        )
    pointer = update_for_windows(
        pointer,
        run_root=args.windows_run,
        runner=args.windows_runner,
        job_id=args.windows_job,
    )
    write_pointer(path, pointer)


if __name__ == "__main__":
    main()
