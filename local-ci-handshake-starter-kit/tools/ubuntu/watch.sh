#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
UBUNTU_OUT="$REPO_ROOT/out/local-ci-ubuntu"
POLL_SEC="${POLL_SEC:-5}"

ingest_and_render() {
  local run_id="$1"
  local run_dir="$UBUNTU_OUT/$run_id"
  local publish="$run_dir/windows/vi-compare.publish.json"
  [ -f "$publish" ] || return 0

  local primary_dir alt_dir raw_src
  primary_dir="$(jq -r '.raw_artifacts.primary_dir' "$publish")"
  alt_dir="$(jq -r '.raw_artifacts.alt_dir // empty' "$publish")"

  if [ -d "$REPO_ROOT/$primary_dir" ]; then raw_src="$REPO_ROOT/$primary_dir"
  elif [ -n "$alt_dir" ] && [ -d "$REPO_ROOT/$alt_dir" ]; then raw_src="$REPO_ROOT/$alt_dir"
  else echo "[ubuntu-watch] No raw dir for $run_id" >&2; return 0
  fi

  mkdir -p "$run_dir/windows/raw" "$run_dir/reports"
  rsync -a --delete "$raw_src/" "$run_dir/windows/raw/"
  python3 tools/ubuntu/render.py \
    --run "$run_id" \
    --raw "$run_dir/windows/raw" \
    --manifest "$run_dir/ubuntu-run.json" \
    --requests "$run_dir/vi-diff-requests.json" \
    --out "$run_dir/reports"
  touch "$run_dir/_DONE"
  echo "[ubuntu-watch] Rendered $run_id"
}

while true; do
  shopt -s nullglob
  for run_dir in "$UBUNTU_OUT"/*; do
    [ -d "$run_dir" ] || continue
    [ -f "$run_dir/_READY" ] || continue
    [ -f "$run_dir/_DONE" ] && continue
    run_id="$(basename "$run_dir")"
    ingest_and_render "$run_id"
  done
  sleep "$POLL_SEC"
done
