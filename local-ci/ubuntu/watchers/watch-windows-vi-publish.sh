#!/usr/bin/env bash
# Watches the Windows publish directory for new vi-compare publish.json files
# and re-runs the Ubuntu render stage when new artifacts arrive.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Resolve repo root via git (preferred) or relative fallback so the watcher can run
# from anywhere without assuming a specific directory depth.
if REPO_ROOT_GIT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then
  REPO_ROOT="$REPO_ROOT_GIT"
else
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
fi

WINDOWS_ROOT="$REPO_ROOT/out/vi-comparison/windows"
RUNS_ROOT="$REPO_ROOT/out/local-ci-ubuntu"
STATE_DIR="$REPO_ROOT/out/local-ci-ubuntu/watchers"
STATE_FILE="$STATE_DIR/vi-publish-state.json"
LOG_DIR="$STATE_DIR"
INTERVAL=30
DEBOUNCE=5
TARGET_RUN=""
RUN_ONCE=false
DRY_RUN=false

usage() {
  cat <<'EOF'
Usage: watch-windows-vi-publish.sh [options]

Options:
  --windows-root <path>   Directory containing Windows publish folders (default out/vi-comparison/windows)
  --runs-root <path>      Directory containing Ubuntu run folders (default out/local-ci-ubuntu)
  --state-dir <path>      Directory to store watcher state/logs (default out/local-ci-ubuntu/watchers)
  --log-dir <path>        Directory for watcher logs (default same as state dir)
  --interval <seconds>    Polling interval when running continuously (default 30)
  --debounce <seconds>    Delay after detecting a publish before rendering (default 5)
  --run <ubuntu_run>      Only process the specified Ubuntu run stamp
  --once                  Process pending publish files once and exit
  --dry-run               Log what would happen without invoking the render stage
  -h, --help              Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --windows-root)
      shift
      WINDOWS_ROOT="$1"
      ;;
    --runs-root)
      shift
      RUNS_ROOT="$1"
      ;;
    --state-dir)
      shift
      STATE_DIR="$1"
      ;;
    --log-dir)
      shift
      LOG_DIR="$1"
      ;;
    --interval)
      shift
      INTERVAL="$1"
      ;;
    --debounce)
      shift
      DEBOUNCE="$1"
      ;;
    --run)
      shift
      TARGET_RUN="$1"
      ;;
    --once)
      RUN_ONCE=true
      ;;
    --dry-run)
      DRY_RUN=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
  shift
done

mkdir -p "$STATE_DIR" "$LOG_DIR" "$RUNS_ROOT"
STATE_FILE="$STATE_DIR/vi-publish-state.json"

WINDOWS_ROOT="$(cd "$WINDOWS_ROOT" && pwd)"
RUNS_ROOT="$(cd "$RUNS_ROOT" && pwd)"
LOG_PATH="$LOG_DIR/vi-publish-watcher.log"

read_state() {
  if [[ -f "$STATE_FILE" ]]; then
    cat "$STATE_FILE"
  else
    echo '{"processed":{}}'
  fi
}

write_state() {
  local json="$1"
  printf '%s\n' "$json" > "$STATE_FILE"
}

log_line() {
  local msg="$1"
  printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$msg" | tee -a "$LOG_PATH"
}

select_publish() {
  python3 - <<'PY' "$WINDOWS_ROOT" "$TARGET_RUN" "$STATE_FILE" "$RUNS_ROOT"
import json, sys
from pathlib import Path
windows_root = Path(sys.argv[1])
target_run = sys.argv[2]
state_path = Path(sys.argv[3])
runs_root = Path(sys.argv[4])
processed = {}
if state_path.is_file():
    try:
        processed = json.loads(state_path.read_text()).get('processed',{})
    except Exception:
        processed = {}

candidates = []
seen = set()

def consider(ubuntu_run, windows_run, publish_path):
    if not ubuntu_run or not windows_run:
        return
    if target_run and ubuntu_run != target_run:
        return
    key = (ubuntu_run, windows_run)
    if key in seen:
        return
    last = processed.get(ubuntu_run)
    if not last or windows_run != last:
        candidates.append((ubuntu_run, windows_run, str(publish_path)))
        seen.add(key)

if runs_root.is_dir():
    for run_dir in sorted(runs_root.iterdir()):
        if not run_dir.is_dir():
            continue
        ubuntu_run = run_dir.name
        publish = run_dir / 'windows' / 'vi-compare.publish.json'
        if not publish.is_file():
            continue
        try:
            data = json.loads(publish.read_text(encoding='utf-8'))
        except Exception:
            continue
        windows_run = data.get('windowsRun')
        consider(ubuntu_run, windows_run or publish.parent.name, publish)

for publish in windows_root.glob('*/publish.json'):
    try:
        data = json.loads(publish.read_text(encoding='utf-8'))
    except Exception:
        continue
    ubuntu_run = data.get('ubuntuPayload')
    windows_run = data.get('windowsRun') or publish.parent.name
    consider(ubuntu_run, windows_run, publish)

if not candidates:
    print('')
else:
    candidates.sort(key=lambda item: item[1])
    ubuntu_run, windows_run, publish_path = candidates[-1]
    output = {
        "ubuntu_run": ubuntu_run,
        "windows_run": windows_run,
        "publish_path": publish_path,
    }
    print(json.dumps(output))
PY
}

render_with_publish() {
  local run_stamp="$1"
  local publish_path="$2"
  local run_dir="$REPO_ROOT/out/local-ci-ubuntu/$run_stamp"
  if [[ ! -d "$run_dir" ]]; then
    log_line "Ubuntu run directory not found: $run_dir"
    return 1
  fi
  if [[ "$DRY_RUN" == "true" ]]; then
    log_line "[dry-run] Would render run $run_stamp with publish $publish_path"
    return 0
  fi
  log_line "Rendering vi-comparison for $run_stamp using publish $publish_path"
  LOCALCI_REPO_ROOT="$REPO_ROOT" \
  LOCALCI_RUN_ROOT="$run_dir" \
  LOCALCI_WINDOWS_PUBLISH_JSON="$publish_path" \
    bash "$REPO_ROOT/local-ci/ubuntu/stages/45-vi-compare.sh"
}

update_state() {
  local run_stamp="$1"
  local windows_run="$2"
  python3 - <<'PY' "$STATE_FILE" "$run_stamp" "$windows_run"
import json, sys
state_path = sys.argv[1]
run_stamp = sys.argv[2]
windows_run = sys.argv[3]
try:
    data = json.loads(open(state_path, 'r', encoding='utf-8').read())
except Exception:
    data = {}
processed = data.get('processed') or {}
processed[run_stamp] = windows_run
data['processed'] = processed
with open(state_path, 'w', encoding='utf-8') as fh:
    json.dump(data, fh, indent=2)
PY
}

process_once() {
  local selection
  selection="$(select_publish)"
  if [[ -z "$selection" ]]; then
    log_line "No new Windows publish files detected."
    return 1
  fi
  local ubuntu_run windows_run publish_path
  ubuntu_run="$(python3 - <<'PY' "$selection"
import json, sys
data=json.loads(sys.argv[1])
print(data['ubuntu_run'])
PY
)"
  windows_run="$(python3 - <<'PY' "$selection"
import json, sys
data=json.loads(sys.argv[1])
print(data['windows_run'])
PY
)"
  publish_path="$(python3 - <<'PY' "$selection"
import json, sys
data=json.loads(sys.argv[1])
print(data['publish_path'])
PY
)"
  sleep "$DEBOUNCE"
  if render_with_publish "$ubuntu_run" "$publish_path"; then
    update_state "$ubuntu_run" "$windows_run"
  fi
  return 0
}

log_line "Watching Windows publish root $WINDOWS_ROOT"

if $RUN_ONCE; then
  if ! process_once; then
    exit 1
  fi
  exit 0
fi

while true; do
  process_once || true
  sleep "$INTERVAL"
done
