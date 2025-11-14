#!/usr/bin/env bash
set -euo pipefail
RUN_ID=""
FORCE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --run) RUN_ID="$2"; shift 2;;
    --force) FORCE=1; shift;;
    *) echo "unknown arg: $1" >&2; exit 1;;
  esac
done
[ -n "$RUN_ID" ] || { echo "--run <run_id> required" >&2; exit 1; }
REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
RUN_DIR="$REPO_ROOT/out/local-ci-ubuntu/$RUN_ID"
[ -d "$RUN_DIR" ] || { echo "no such run: $RUN_DIR" >&2; exit 1; }
PUBLISH="$RUN_DIR/windows/vi-compare.publish.json"
[ -f "$PUBLISH" ] || { echo "missing summary: $PUBLISH" >&2; exit 1; }

primary_dir=$(jq -r '.raw_artifacts.primary_dir' "$PUBLISH")
alt_dir=$(jq -r '.raw_artifacts.alt_dir // empty' "$PUBLISH")
raw_src=""
if [ -d "$REPO_ROOT/$primary_dir" ]; then raw_src="$REPO_ROOT/$primary_dir"
elif [ -n "$alt_dir" ] && [ -d "$REPO_ROOT/$alt_dir" ]; then raw_src="$REPO_ROOT/$alt_dir"
else echo "No raw dir present for $RUN_ID" >&2; exit 1
fi

mkdir -p "$RUN_DIR/windows/raw" "$RUN_DIR/reports"
rsync -a --delete "$raw_src/" "$RUN_DIR/windows/raw/"
python3 tools/ubuntu/render.py --run "$RUN_ID" --raw "$RUN_DIR/windows/raw" --manifest "$RUN_DIR/ubuntu-run.json" --requests "$RUN_DIR/vi-diff-requests.json" --out "$RUN_DIR/reports"
touch "$RUN_DIR/_DONE"
echo "Rendered $RUN_ID"
