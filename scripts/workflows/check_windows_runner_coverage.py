#!/usr/bin/env python3
"""Validate self-hosted Windows runner coverage for the handshake workflow."""

from __future__ import annotations

import json
import os
import sys
import urllib.request
from urllib.error import HTTPError, URLError
from typing import Iterable, List, Sequence


def emit_error(message: str) -> None:
    print(f"::error::{message}")
    raise SystemExit(1)


def parse_labels(raw: str) -> List[str]:
    if not raw.strip():
        emit_error("WINDOWS_RUNNER_LABELS is empty; expected JSON array.")
    try:
        parsed = json.loads(raw)
    except Exception as exc:  # noqa: BLE001
        emit_error(f"Failed to parse WINDOWS_RUNNER_LABELS as JSON: {exc}")
    if not isinstance(parsed, list) or not parsed:
        emit_error("WINDOWS_RUNNER_LABELS must be a JSON array with at least one label.")
    labels: List[str] = []
    for label in parsed:
        if not isinstance(label, str) or not label.strip():
            emit_error("WINDOWS_RUNNER_LABELS entries must be non-empty strings.")
        labels.append(label.strip())
    return labels


def request_runners(repo: str, token: str, api_url: str) -> List[dict]:
    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
    }
    url = f"{api_url}/repos/{repo}/actions/runners?per_page=100"
    runners: List[dict] = []
    while url:
        req = urllib.request.Request(url, headers=headers)
        try:
            with urllib.request.urlopen(req) as response:  # noqa: S310
                data = json.load(response)
                runners.extend(data.get("runners", []))
                link_header = response.headers.get("Link")
        except HTTPError:
            raise
        except URLError as exc:
            emit_error(f"Failed to query runner inventory: {exc}")
        next_url = None
        if link_header:
            for segment in link_header.split(","):
                segment = segment.strip()
                if segment.endswith('rel="next"'):
                    start = segment.find("<") + 1
                    end = segment.find(">")
                    next_url = segment[start:end]
                    break
        url = next_url
    return runners


def summarize_runner(runner: dict) -> tuple[str, List[str]]:
    labels = [label.get("name", "") for label in runner.get("labels", []) if label.get("name")]
    name = runner.get("name") or "<unnamed>"
    return name, labels


def format_inventory(runners: Iterable[dict]) -> Sequence[str]:
    lines: List[str] = []
    for runner in runners:
        name, labels = summarize_runner(runner)
        state = runner.get("status", "unknown")
        label_text = ", ".join(labels) if labels else "<no labels>"
        lines.append(f"{name} ({state}): {label_text}")
    return lines


def write_summary(
    required_labels: Sequence[str],
    matches: Sequence[str],
    inventory: Sequence[str],
    note: str | None = None,
) -> None:
    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if not summary_path:
        return
    lines = [
        "### Windows Runner Coverage",
        "",
        f"- Required labels: {', '.join(required_labels)}",
    ]
    if matches:
        lines.append(f"- Matching online runners: {', '.join(sorted(matches))}")
    else:
        lines.append("- Matching online runners: <none>")
    if note:
        lines.append(f"- Note: {note}")
    if inventory:
        lines.append("")
        lines.append("Runner inventory snapshot:")
        lines.extend(f"- {entry}" for entry in inventory)
    with open(summary_path, "a", encoding="utf-8") as handle:
        handle.write("\n".join(lines) + "\n")


def main() -> None:
    raw_labels = os.environ.get("WINDOWS_RUNNER_LABELS", "")
    labels = parse_labels(raw_labels)

    token = os.environ.get("GITHUB_TOKEN") or ""
    if not token:
        emit_error("GITHUB_TOKEN is missing; cannot query runner inventory.")
    repo = os.environ.get("GITHUB_REPOSITORY")
    if not repo:
        emit_error("GITHUB_REPOSITORY is missing.")
    api_url = os.environ.get("GITHUB_API_URL", "https://api.github.com").rstrip("/")

    try:
        runners = request_runners(repo, token, api_url)
    except HTTPError as exc:
        if exc.code == 403:
            note = (
                "Runner inventory API returned 403 (insufficient privileges); "
                "skipping coverage enforcement."
            )
            print(f"::warning::{note}")
            write_summary(labels, [], [], note)
            return
        emit_error(f"Failed to query runner inventory: HTTP {exc.code}")
    matches: List[str] = []
    for runner in runners:
        if runner.get("status") != "online":
            continue
        name, runner_labels = summarize_runner(runner)
        if all(label in runner_labels for label in labels):
            matches.append(name)

    inventory = format_inventory(runners)
    write_summary(labels, matches, inventory)

    if matches:
        print(f"Found matching online runners: {', '.join(sorted(matches))}")
    else:
        emit_error(
            "No online self-hosted runner advertises the required labels: "
            f"{', '.join(labels)}"
        )


if __name__ == "__main__":
    main()
