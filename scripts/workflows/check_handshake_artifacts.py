#!/usr/bin/env python3
"""Heuristics to validate Ubuntu handshake artifacts before Windows consumes them."""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any, Dict


def fail(message: str) -> None:
    print(f"::error::{message}")
    raise SystemExit(1)


def load_json(path: Path) -> Dict[str, Any]:
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError as exc:
        fail(f"Required file not found: {exc.filename}")
    except json.JSONDecodeError as exc:
        fail(f"Failed to parse JSON from {path}: {exc}")


def resolve_repo_path(repo_root: Path, candidate: str | None) -> Path | None:
    if not candidate:
        return None
    candidate_path = Path(candidate)
    if not candidate_path.is_absolute():
        candidate_path = (repo_root / candidate_path).resolve()
    return candidate_path


def validate_manifest(manifest: Dict[str, Any], manifest_path: Path) -> None:
    required_top = [
        "schema_version",
        "run_id",
        "created_utc",
        "project",
        "tooling",
        "vi_diff_requests_file",
    ]
    for key in required_top:
        if key not in manifest:
            fail(f"Manifest missing required field '{key}' at {manifest_path}")
    project = manifest["project"]
    for field in ("name", "repo", "branch", "commit"):
        value = project.get(field)
        if not value or not isinstance(value, str):
            fail(f"Manifest project.{field} missing/invalid in {manifest_path}")
    repo_value = project["repo"]
    if "/" not in repo_value:
        fail(f"Manifest project.repo '{repo_value}' is not owner/name format.")
    tooling = manifest["tooling"]
    for field in ("ubuntu_ci_tool_version", "renderer_version"):
        value = tooling.get(field)
        if not value or not isinstance(value, str):
            fail(f"Manifest tooling.{field} missing/invalid in {manifest_path}")
    if manifest["schema_version"] != "v1":
        fail(f"Manifest schema_version '{manifest['schema_version']}' is not v1.")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", required=True, help="Path to ubuntu-run.json")
    parser.add_argument("--pointer", required=True, help="Path to handshake pointer")
    parser.add_argument("--repo-root", default=".", help="Repository root (for relative paths)")
    parser.add_argument("--stamp", help="Expected Ubuntu stamp")
    parser.add_argument("--artifact-dir", help="Expected artifact directory containing manifest")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    manifest_path = Path(args.manifest).resolve()
    pointer_path = Path(args.pointer).resolve()
    if not manifest_path.is_file():
        fail(f"Manifest not found at {manifest_path}")
    if not pointer_path.is_file():
        fail(f"Handshake pointer not found at {pointer_path}")
    manifest_dir = manifest_path.parent
    if args.artifact_dir:
        artifact_dir = Path(args.artifact_dir).resolve()
        if artifact_dir != manifest_dir:
            fail(
                f"Manifest directory {manifest_dir} does not match expected artifact dir {artifact_dir}"
            )
    manifest = load_json(manifest_path)
    validate_manifest(manifest, manifest_path)
    vi_diff_requests = manifest["vi_diff_requests_file"]
    vi_diff_path = Path(vi_diff_requests)
    if not vi_diff_path.is_absolute():
        vi_diff_path = (manifest_dir / vi_diff_path).resolve()
    if not vi_diff_path.is_file():
        fail(f"vi_diff_requests_file '{vi_diff_requests}' not found relative to manifest.")

    pointer = load_json(pointer_path)
    if pointer.get("schema") != "handshake/v1":
        fail(f"Handshake pointer schema must be handshake/v1 (found {pointer.get('schema')})")
    ubuntu_info = pointer.get("ubuntu") or {}
    manifest_abs = ubuntu_info.get("manifest_abs")
    if manifest_abs:
        resolved = Path(manifest_abs).resolve()
        if resolved != manifest_path:
            fail(f"Pointer manifest_abs {resolved} does not match manifest {manifest_path}")
    if args.stamp and ubuntu_info.get("stamp") != args.stamp:
        fail(
            f"Pointer Ubuntu stamp {ubuntu_info.get('stamp')} does not match expected {args.stamp}"
        )
    artifact_name = ubuntu_info.get("artifact")
    if not artifact_name:
        fail("Handshake pointer ubuntu.artifact is missing.")
    pointer_ref = ubuntu_info.get("pointer")
    if pointer_ref:
        pointer_file = resolve_repo_path(repo_root, pointer_ref)
        if not pointer_file or not pointer_file.is_file():
            fail(f"Ubuntu latest pointer referenced at '{pointer_ref}' does not exist.")

    print("Handshake heuristics succeeded:")
    print(f"- Manifest: {manifest_path}")
    print(f"- Pointer: {pointer_path}")
    print(f"- Artifact: {artifact_name}")


if __name__ == "__main__":
    main()
