#!/usr/bin/env python3
"""Analyze handshake pointer metadata to detect stale Ubuntu->Windows transfers."""

from __future__ import annotations

import argparse
import json
import os
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Optional


@dataclass
class PointerStatus:
    status: str
    ubuntu_stamp: str
    ubuntu_updated_at: Optional[datetime]
    windows_status: Optional[str]
    windows_updated_at: Optional[datetime]
    windows_runner: Optional[str]
    windows_run_root: Optional[str]


def parse_timestamp(raw: Optional[str]) -> Optional[datetime]:
    if not raw:
        return None
    try:
        return datetime.fromisoformat(raw.replace("Z", "+00:00")).astimezone(timezone.utc)
    except ValueError:
        return None


def load_pointer(path: Path) -> PointerStatus:
    with path.open("r", encoding="utf-8") as handle:
        data = json.load(handle)
    ubuntu = data.get("ubuntu") or {}
    windows = data.get("windows") or {}
    return PointerStatus(
        status=str(data.get("status") or "unknown"),
        ubuntu_stamp=str(ubuntu.get("stamp") or ""),
        ubuntu_updated_at=parse_timestamp(ubuntu.get("updated_at")),
        windows_status=(windows.get("status") or None),
        windows_updated_at=parse_timestamp(windows.get("updated_at")),
        windows_runner=(windows.get("runner") or None),
        windows_run_root=(windows.get("run_root") or None),
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pointer", required=True, help="Path to handshake pointer JSON.")
    parser.add_argument(
        "--ttl-minutes",
        type=int,
        default=60,
        help="Minutes to wait before declaring a lease stale when Windows has not acknowledged.",
    )
    parser.add_argument("--summary", help="Optional path to write JSON summary.")
    args = parser.parse_args()

    pointer = load_pointer(Path(args.pointer))
    now = datetime.now(timezone.utc)
    ttl = timedelta(minutes=args.ttl_minutes)
    ubuntu_age = None
    windows_age = None
    needs_attention = False
    reason = ""

    if pointer.ubuntu_updated_at:
        ubuntu_age = (now - pointer.ubuntu_updated_at).total_seconds() / 60
    if pointer.windows_updated_at:
        windows_age = (now - pointer.windows_updated_at).total_seconds() / 60

    if pointer.status == "ubuntu-ready":
        if pointer.ubuntu_updated_at and now - pointer.ubuntu_updated_at > ttl:
            needs_attention = True
            reason = (
                f"Ubuntu run {pointer.ubuntu_stamp} has waited "
                f"{int(ubuntu_age or 0)} min without a Windows import."
            )
        else:
            reason = "Ubuntu payload ready; awaiting Windows import."
    elif pointer.status == "windows-ack":
        reason = "Windows runner acknowledged import."
        # If we had an acknowledge but the data is stale for a long time we can still warn.
        if pointer.windows_updated_at and now - pointer.windows_updated_at > ttl * 12:
            needs_attention = True
            reason = (
                f"Windows run idle for {int(windows_age or 0)} min without publish update."
            )
    else:
        needs_attention = True
        reason = f"Unknown pointer status '{pointer.status}'."

    summary: dict[str, Any] = {
        "pointer_path": str(Path(args.pointer)),
        "status": pointer.status,
        "ubuntu_stamp": pointer.ubuntu_stamp,
        "ubuntu_age_minutes": ubuntu_age,
        "windows_status": pointer.windows_status,
        "windows_runner": pointer.windows_runner,
        "windows_run_root": pointer.windows_run_root,
        "windows_age_minutes": windows_age,
        "needs_attention": needs_attention,
        "reason": reason,
        "checked_at": now.isoformat(),
        "ttl_minutes": args.ttl_minutes,
    }

    summary_path = Path(args.summary) if args.summary else None
    if summary_path:
        summary_path.parent.mkdir(parents=True, exist_ok=True)
        with summary_path.open("w", encoding="utf-8") as handle:
            json.dump(summary, handle, indent=2)
            handle.write("\n")

    github_output = os.environ.get("GITHUB_OUTPUT")
    if github_output:
        with open(github_output, "a", encoding="utf-8") as handle:
            handle.write(f"needs_attention={'true' if needs_attention else 'false'}\n")
            handle.write(f"reason<<EOF\n{reason}\nEOF\n")
            handle.write(f"pointer_stamp={pointer.ubuntu_stamp}\n")

    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
