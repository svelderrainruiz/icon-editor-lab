#!/usr/bin/env python3
import argparse
import subprocess
import sys
from pathlib import Path

parser = argparse.ArgumentParser(description="Detect changed VI files between two refs")
parser.add_argument("--repo", required=True)
parser.add_argument("--base", required=False)
parser.add_argument("--head", default="HEAD")
parser.add_argument("--output", required=True)
args = parser.parse_args()

repo = Path(args.repo)
out_path = Path(args.output)
base = args.base
head = args.head
if not base:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text("", encoding="utf-8")
    sys.exit(0)
cmd = [
    "git",
    "-C",
    str(repo),
    "diff",
    "--name-only",
    f"{base}...{head}",
    "--",
    "*.vi",
]
proc = subprocess.run(cmd, capture_output=True, text=True)
if proc.returncode != 0:
    sys.stderr.write(proc.stderr)
    sys.exit(proc.returncode)
files = [line.strip() for line in proc.stdout.splitlines() if line.strip()]
out_path.parent.mkdir(parents=True, exist_ok=True)
out_path.write_text("\n".join(files), encoding="utf-8")
