#!/usr/bin/env python3
"""Heuristics to validate Ubuntu handshake artifacts before Windows consumes them."""

from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, Iterable, List, Sequence


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


def ensure_file(path: Path, description: str) -> None:
    if not path.is_file():
        fail(f"{description} not found at {path}")
    if path.stat().st_size == 0:
        fail(f"{description} at {path} is empty.")


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
    created = manifest["created_utc"]
    try:
        datetime.fromisoformat(created.replace("Z", "+00:00"))
    except ValueError as exc:
        fail(f"Manifest created_utc '{created}' is not ISO-8601: {exc}")

    tooling = manifest["tooling"]
    for field in ("ubuntu_ci_tool_version", "renderer_version"):
        value = tooling.get(field)
        if not value or not isinstance(value, str):
            fail(f"Manifest tooling.{field} missing/invalid in {manifest_path}")
    if manifest["schema_version"] != "v1":
        fail(f"Manifest schema_version '{manifest['schema_version']}' is not v1.")

    path_map = manifest.get("path_map") or []
    if not isinstance(path_map, list) or not path_map:
        fail("Manifest path_map must include at least one entry.")
    for idx, entry in enumerate(path_map):
        if not isinstance(entry, dict):
            fail(f"Manifest path_map entry {idx} is not an object.")
        for field in ("purpose", "windows", "wsl"):
            value = entry.get(field)
            if not value or not isinstance(value, str):
                fail(f"Manifest path_map[{idx}].{field} missing or invalid.")
        if "\\" not in entry["windows"]:
            fail(f"path_map[{idx}].windows should be a Windows path (found {entry['windows']}).")
        if not entry["wsl"].startswith("/"):
            fail(f"path_map[{idx}].wsl should be a POSIX path (found {entry['wsl']}).")

    determinism = manifest.get("determinism") or {}
    if determinism:
        if determinism.get("sort") not in ("lexicographic", "numeric"):
            fail(
                f"determinism.sort must be lexicographic or numeric (found {determinism.get('sort')})."
            )
        if determinism.get("locale") not in (None, "C", "en_US"):
            fail(
                f"determinism.locale {determinism.get('locale')} is unexpected; expected 'C' or 'en_US'."
            )
        if "case_sensitive" in determinism and not isinstance(
            determinism["case_sensitive"], bool
        ):
            fail("determinism.case_sensitive must be a boolean when provided.")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", required=True, help="Path to ubuntu-run.json")
    parser.add_argument("--pointer", required=True, help="Path to handshake pointer")
    parser.add_argument("--repo-root", default=".", help="Repository root (for relative paths)")
    parser.add_argument("--stamp", help="Expected Ubuntu stamp")
    parser.add_argument("--artifact-dir", help="Expected artifact directory containing manifest")
    parser.add_argument("--github-repository", help="Expected project.repo owner/name")
    parser.add_argument(
        "--expect-windows-status",
        default="pending",
        help="Expected handshake pointer windows.status value before Windows job runs",
    )
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
    project_repo = manifest["project"].get("repo")
    if args.github_repository and project_repo != args.github_repository:
        fail(
            f"Manifest project.repo '{project_repo}' does not match expected '{args.github_repository}'."
        )

    artifacts = manifest.get("artifacts") or {}
    artifact_zip = artifacts.get("zip")
    if not artifact_zip:
        fail("Manifest artifacts.zip is missing.")
    artifact_zip_path = Path(artifact_zip)
    if not artifact_zip_path.is_absolute():
        artifact_zip_path = (repo_root / artifact_zip_path).resolve()
    ensure_file(artifact_zip_path, "Artifacts ZIP")
    checksums = artifacts.get("checksums") or {}
    if not isinstance(checksums, dict) or not checksums:
        fail("Manifest artifacts.checksums must include at least one entry.")
    if Path(artifact_zip).name not in checksums:
        fail(
            f"Manifest checksums missing entry for {Path(artifact_zip).name}; found {list(checksums.keys())}"
        )
    for filename, checksum in checksums.items():
        if not isinstance(checksum, str) or ":" not in checksum:
            fail(f"Checksum entry for {filename} must be an algorithm:value string.")
        checksum_path = manifest_dir / filename
        if checksum_path.exists():
            ensure_file(checksum_path, f"Checksum target {filename}")

    vi_diff_requests = manifest["vi_diff_requests_file"]
    vi_diff_path = Path(vi_diff_requests)
    if not vi_diff_path.is_absolute():
        candidate = (manifest_dir / vi_diff_path).resolve()
        if candidate.is_file():
            vi_diff_path = candidate
        else:
            repo_candidate = (repo_root / vi_diff_path).resolve()
            if repo_candidate.is_file():
                vi_diff_path = repo_candidate
            else:
                vi_diff_path = candidate
    ensure_file(vi_diff_path, "vi_diff_requests_file")

    pointer = load_json(pointer_path)
    if pointer.get("schema") != "handshake/v1":
        fail(f"Handshake pointer schema must be handshake/v1 (found {pointer.get('schema')})")
    if pointer.get("status") not in ("ubuntu-ready", "windows-ack"):
        fail(f"Handshake pointer status {pointer.get('status')} not recognized.")
    if pointer.get("ubuntu") is None:
        fail("Handshake pointer missing ubuntu section.")
    windows_block = pointer.get("windows")
    if windows_block is None:
        fail("Handshake pointer missing windows section.")
    expected_windows = args.expect_windows_status
    if expected_windows and windows_block.get("status") != expected_windows:
        fail(
            f"Handshake pointer windows.status {windows_block.get('status')} "
            f"does not match expected {expected_windows}"
        )
    if expected_windows == "pending":
        if windows_block.get("run_root"):
            fail("Handshake pointer windows.run_root should be null before Windows job.")
    else:
        if not windows_block.get("run_root"):
            fail("Handshake pointer windows.run_root missing when status is not pending.")
    if pointer.get("sequence") is None or not isinstance(pointer["sequence"], int):
        fail("Handshake pointer sequence missing or not an integer.")
    if not pointer.get("last_updated"):
        fail("Handshake pointer missing last_updated timestamp.")
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
